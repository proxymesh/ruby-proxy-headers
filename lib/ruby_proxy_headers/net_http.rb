# frozen_string_literal: true

require 'net/http'
require 'openssl'

# Loaded for header validation. Requiring this file first is safe: the parent
# requires it back and Ruby drops the cycle.
require_relative '../ruby_proxy_headers'

module RubyProxyHeaders
  # Patches Net::HTTP so an HTTPS request through a proxy can send extra CONNECT
  # headers and keep the proxy's CONNECT response.
  #
  # The patch does not copy +Net::HTTP#connect+. The installed net-http still
  # owns the socket, +timeouted_connect+, and HTTPS-to-proxy (+proxy_use_ssl+).
  # A prepend validates the target, then rewrites the CONNECT bytes that
  # upstream writes and records the CONNECT response.
  #
  # @example
  #   require 'ruby_proxy_headers/net_http'
  #   RubyProxyHeaders::NetHTTP.patch!
  #
  #   http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
  #   http.use_ssl = true
  #   http.proxy_connect_request_headers = { 'X-ProxyMesh-IP' => '203.0.113.1' }
  #   res = http.request(Net::HTTP::Get.new(uri))
  #   p http.last_proxy_connect_response_headers['X-ProxyMesh-IP']
  module NetHTTP
    # Inserts +headers+ before the blank line that ends a CONNECT request.
    def self.inject_connect_headers(buf, headers)
      return buf if headers.nil? || headers.empty?

      headers.each { |key, value| RubyProxyHeaders.validate_header!(key, value) }

      extra = String.new(encoding: buf.encoding)
      headers.each do |key, value|
        extra << "#{key}: #{value}\r\n".encode(buf.encoding)
      end
      "#{buf.sub(/\r\n\r\n\z/, "\r\n")}#{extra}\r\n"
    end

    # Rewrites a CONNECT write while a patched connection is opening.
    module ConnectRequestWrite
      def write(*strs)
        http = Thread.current[:ruby_proxy_headers_active_http]
        joined = strs.join
        if http && joined.start_with?('CONNECT ')
          strs = [
            RubyProxyHeaders::NetHTTP.inject_connect_headers(
              joined,
              http.proxy_connect_request_headers
            )
          ]
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
          headers = HeaderMap.new
          response.each_header { |key, value| headers[key] = value }
          http.instance_variable_set(:@last_proxy_connect_response_headers, headers)
          Thread.current[:ruby_proxy_headers_connect_headers] = headers.dup
        end
        response
      end
    end

    # Instance methods prepended onto Net::HTTP.
    module Extension
      attr_accessor :proxy_connect_request_headers
      attr_reader :last_proxy_connect_response_headers

      def connect
        return super unless use_ssl? && proxy?

        # Reject smuggled targets and header values before any socket I/O.
        RubyProxyHeaders.validate_connect_target!(conn_address, @port)
        RubyProxyHeaders.validate_connect_target!(@address, @port)
        proxy_connect_request_headers&.each do |key, value|
          RubyProxyHeaders.validate_header!(key, value)
        end

        @last_proxy_connect_response_headers = nil
        previous_http = Thread.current[:ruby_proxy_headers_active_http]
        previous_headers = Thread.current[:ruby_proxy_headers_connect_headers]
        begin
          Thread.current[:ruby_proxy_headers_active_http] = self
          Thread.current[:ruby_proxy_headers_connect_headers] = nil
          super
        ensure
          Thread.current[:ruby_proxy_headers_active_http] = previous_http
          if Thread.current[:ruby_proxy_headers_connect_headers].nil?
            Thread.current[:ruby_proxy_headers_connect_headers] = previous_headers
          end
        end
      end
    end

    class << self
      def patch!
        @patch_mutex ||= Mutex.new
        @patch_mutex.synchronize do
          return if @patched

          # WebMock replaces Net::HTTP with a subclass created before patch!.
          # Prepend the original class so that subclass inherits it, including
          # after WebMock.disable! puts the original constant back.
          classes = [::Net::HTTP]
          if defined?(::WebMock::HttpLibAdapters::NetHttpAdapter)
            classes.unshift(::WebMock::HttpLibAdapters::NetHttpAdapter::OriginalNetHTTP)
          end
          classes.uniq.each do |klass|
            klass.prepend(Extension) unless klass.ancestors.include?(Extension)
          end
          ::Net::BufferedIO.prepend(ConnectRequestWrite)
          ::Net::HTTPResponse.singleton_class.prepend(ConnectResponseRead)
          @patched = true
        end
      end

      def patched?
        @patched == true
      end
    end
  end
end
