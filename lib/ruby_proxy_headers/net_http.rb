# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'uri'

# Loaded for header validation. Safe if this file is required first: the parent
# file requires us back and Ruby drops the cycle.
require_relative '../ruby_proxy_headers'

module RubyProxyHeaders
  # Case-insensitive view of HTTP headers. Keys are stored downcased, which is
  # how Net::HTTP yields them, and looked up regardless of case.
  class HeaderHash < Hash
    def [](key)
      return nil if key.nil?

      super(normalize(key))
    end

    def []=(key, value)
      super(normalize(key), value)
    end

    def store(key, value)
      self[key] = value
    end

    def fetch(key, *args, &block)
      super(normalize(key), *args, &block)
    end

    def key?(key)
      super(normalize(key))
    end
    alias has_key? key?
    alias include? key?
    alias member? key?

    private

    def normalize(key)
      key.to_s.downcase
    end
  end

  # Patches Net::HTTP so HTTPS-through-proxy can send extra CONNECT headers and
  # keep the proxy's CONNECT response headers.
  #
  # The patch does not copy +Net::HTTP#connect+. Upstream owns socket setup,
  # +timeouted_connect+, and HTTPS-to-proxy (+@proxy_use_ssl+). We only wrap
  # that method and adjust the CONNECT bytes it writes.
  #
  # @example
  #   require 'ruby_proxy_headers/net_http'
  #   RubyProxyHeaders::NetHTTP.patch!
  #
  #   http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
  #   http.use_ssl = true
  #   http.proxy_connect_request_headers = { 'X-ProxyMesh-IP' => '203.0.113.1' }
  #   res = http.request(Net::HTTP::Get.new(uri))
  #   p http.last_proxy_connect_response_headers
  module NetHTTP
    REQUEST_CLASSES = {
      get: ::Net::HTTP::Get,
      post: ::Net::HTTP::Post,
      put: ::Net::HTTP::Put,
      delete: ::Net::HTTP::Delete,
      head: ::Net::HTTP::Head,
      patch: ::Net::HTTP::Patch,
      options: ::Net::HTTP::Options
    }.freeze

    # Inserts +headers+ before the terminating blank line of a CONNECT request.
    def self.inject_connect_headers(buf, headers)
      return buf if headers.nil? || headers.empty?

      validate_request_headers!(headers)
      unless buf.end_with?("\r\n\r\n")
        raise ArgumentError,
              'upstream CONNECT request has no header terminator; ' \
              'ruby-proxy-headers cannot add proxy headers'
      end

      extra = String.new(encoding: buf.encoding)
      headers.each do |key, value|
        extra << "#{key}: #{value}\r\n".encode(buf.encoding)
      end
      "#{buf.sub(/\r\n\r\n\z/, "\r\n")}#{extra}\r\n"
    end

    def self.validate_request_headers!(headers)
      return if headers.nil?

      headers.each do |key, value|
        RubyProxyHeaders.validate_header!(key, value)
      end
    end

    def self.headers_from(response)
      headers = HeaderHash.new
      response.each_header { |key, value| headers[key] = value }
      headers
    end

    # HTTPS CONNECT through a proxy, with optional extra CONNECT headers.
    #
    # @param method [Symbol, String]
    # @param url [String]
    # @param proxy [String] proxy URL (http:// or https://)
    # @param proxy_headers [Hash, nil]
    # @param headers [Hash, nil] origin request headers
    # @param body [String, nil]
    # @param verify_ssl [Boolean]
    # @return [ProxyResponse]
    def self.request(method, url, proxy:, proxy_headers: nil, headers: nil, body: nil,
                     verify_ssl: true, open_timeout: nil, read_timeout: nil)
      patch!
      uri = URI(url)
      proxy_uri = parse_proxy(proxy)
      http = build_http(
        uri, proxy_uri,
        verify_ssl: verify_ssl,
        open_timeout: open_timeout,
        read_timeout: read_timeout
      )
      http.proxy_connect_request_headers = proxy_headers if proxy_headers&.any?

      req = request_class(method).new(uri.request_uri)
      headers&.each { |key, value| req[key.to_s] = value }
      req.body = body if !body.nil? && req.request_body_permitted?

      response = http.request(req)
      ProxyResponse.new(response, http.last_proxy_connect_response_headers)
    end

    def self.get(url, **options)
      request(:get, url, **options)
    end

    def self.post(url, body = nil, **options)
      body = options.delete(:body) if body.nil? && options.key?(:body)
      request(:post, url, body: body, **options)
    end

    def self.put(url, body = nil, **options)
      body = options.delete(:body) if body.nil? && options.key?(:body)
      request(:put, url, body: body, **options)
    end

    def self.delete(url, **options)
      request(:delete, url, **options)
    end

    def self.parse_proxy(proxy)
      value = proxy.to_s.strip
      value = "http://#{value}" unless value.match?(%r{\A[a-z][a-z0-9+\-.]*://}i)
      URI.parse(value)
    end

    def self.build_http(uri, proxy_uri, verify_ssl:, open_timeout:, read_timeout:)
      http = ::Net::HTTP.new(
        uri.host,
        uri.port,
        proxy_uri.host,
        proxy_uri.port,
        decode_component(proxy_uri.user),
        decode_component(proxy_uri.password)
      )
      if proxy_uri.scheme == 'https'
        unless http.respond_to?(:proxy_use_ssl=)
          version = defined?(::Net::HTTP::VERSION) ? ::Net::HTTP::VERSION : 'unknown'
          raise ArgumentError,
                "HTTPS proxies require net-http >= 0.5 (proxy_use_ssl); loaded net-http #{version}"
        end
        http.proxy_use_ssl = true
      end
      http.use_ssl = uri.scheme == 'https'
      unless verify_ssl
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        http.verify_hostname = false if http.respond_to?(:verify_hostname=)
      end
      http.open_timeout = open_timeout if open_timeout
      http.read_timeout = read_timeout if read_timeout
      http
    end

    def self.decode_component(value)
      return nil if value.nil?

      URI.decode_www_form_component(value)
    rescue ArgumentError
      value
    end

    def self.request_class(method)
      REQUEST_CLASSES.fetch(method.to_s.downcase.to_sym) do
        raise ArgumentError, "unsupported HTTP method: #{method.inspect}"
      end
    end

    # Rewrites the CONNECT request while a patched connection is opening.
    module ConnectRequestWrite
      def write(*strs)
        http = Thread.current[:ruby_proxy_headers_active_http]
        if http && strs.all? { |part| part.is_a?(String) }
          joined = strs.join
          if joined.start_with?('CONNECT ')
            strs = [
              RubyProxyHeaders::NetHTTP.inject_connect_headers(
                joined,
                http.proxy_connect_request_headers
              )
            ]
          end
        end
        super(*strs)
      end
    end

    # Records CONNECT response headers. Active only while #connect is running,
    # so the later origin response is left alone.
    module ConnectResponseRead
      def read_new(sock)
        response = super
        http = Thread.current[:ruby_proxy_headers_active_http]
        if http
          headers = RubyProxyHeaders::NetHTTP.headers_from(response)
          http.instance_variable_set(:@last_proxy_connect_response_headers, headers)
          Thread.current[:ruby_proxy_headers_connect_headers] = headers.dup
        end
        response
      end
    end

    module Extension
      attr_accessor :proxy_connect_request_headers
      attr_reader :last_proxy_connect_response_headers

      def connect
        return super unless use_ssl? && proxy?

        # Reject smuggled targets and header values before any socket I/O.
        # `super` is upstream Net::HTTP#connect (timeouted_connect, HTTPS proxies).
        RubyProxyHeaders.validate_connect_target!(conn_address, @port)
        RubyProxyHeaders.validate_connect_target!(@address, @port)
        RubyProxyHeaders::NetHTTP.validate_request_headers!(proxy_connect_request_headers)

        @last_proxy_connect_response_headers = nil
        previous = Thread.current[:ruby_proxy_headers_active_http]
        begin
          Thread.current[:ruby_proxy_headers_active_http] = self
          super
        ensure
          Thread.current[:ruby_proxy_headers_active_http] = previous
        end
      end
    end

    class ProxyResponse
      attr_reader :proxy_response_headers, :body, :headers, :response

      def initialize(response, proxy_headers)
        @response = response
        @body = response.body
        @headers = RubyProxyHeaders::NetHTTP.headers_from(response)
        @proxy_response_headers = proxy_headers || HeaderHash.new
      end

      def code
        @response.code.to_i
      end

      def success?
        (200..299).cover?(code)
      end

      def method_missing(name, *args, &block)
        if @response.respond_to?(name)
          @response.public_send(name, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        @response.respond_to?(name, include_private) || super
      end
    end

    class << self
      def patch!
        return if @patched

        @patch_mutex ||= Mutex.new
        @patch_mutex.synchronize do
          return if @patched

          ::Net::HTTP.prepend(Extension)
          ::Net::BufferedIO.prepend(ConnectRequestWrite)
          ::Net::HTTPResponse.singleton_class.prepend(ConnectResponseRead)
          @patched = true
        end
      end

      def patched?
        @patched == true
      end
    end
    private_class_method :build_http, :decode_component, :request_class, :parse_proxy
  end
end
