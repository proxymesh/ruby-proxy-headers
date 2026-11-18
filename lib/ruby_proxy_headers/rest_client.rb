# frozen_string_literal: true

require 'delegate'
require 'openssl'
require 'uri'
require_relative '../ruby_proxy_headers'

begin
  require 'rest-client'
rescue LoadError => e
  raise LoadError, "rest-client is required for ruby_proxy_headers/rest_client (#{e.message})"
end

module RubyProxyHeaders
  # RestClient uses Net::HTTP. HTTPS requests go through that client so
  # redirects and payloads stay RestClient's. The Net::HTTP patch attaches
  # CONNECT headers and records +X-ProxyMesh-IP+.
  #
  # @example
  #   response = RubyProxyHeaders::RestClient.get(
  #     'https://example.com',
  #     proxy: 'http://user:pass@proxy.example.com:31280',
  #     proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  #   )
  #   puts response.proxy_response_headers['X-ProxyMesh-IP']
  module RestClient
    # Sets CONNECT headers on the Net::HTTP object RestClient is about to use.
    module NetHttpHook
      # Applies thread-local proxy CONNECT headers to the Net::HTTP instance RestClient will use.
      def net_http_object(hostname, port)
        http = super
        headers = Thread.current[:ruby_proxy_headers_rest_client_headers]
        http.proxy_connect_request_headers = headers if headers&.any?
        http
      end
    end

    class << self
      # GET through a proxy, returning proxy response headers from CONNECT when HTTPS.
      def get(url, proxy:, proxy_headers: {}, **options)
        request(:get, url, proxy: proxy, proxy_headers: proxy_headers, **options)
      end

      # POST through a proxy, returning proxy response headers from CONNECT when HTTPS.
      def post(url, proxy:, proxy_headers: {}, payload: nil, **options)
        request(:post, url, proxy: proxy, proxy_headers: proxy_headers, payload: payload, **options)
      end

      # PUT through a proxy, returning proxy response headers from CONNECT when HTTPS.
      def put(url, proxy:, proxy_headers: {}, payload: nil, **options)
        request(:put, url, proxy: proxy, proxy_headers: proxy_headers, payload: payload, **options)
      end

      # DELETE through a proxy, returning proxy response headers from CONNECT when HTTPS.
      def delete(url, proxy:, proxy_headers: {}, **options)
        request(:delete, url, proxy: proxy, proxy_headers: proxy_headers, **options)
      end

      # Runs an arbitrary RestClient verb through the proxy with optional proxy headers on CONNECT.
      def request(method, url, proxy:, proxy_headers: {}, **options)
        install!
        headers = proxy_headers || {}
        https = URI.parse(url).scheme == 'https'
        headers.each { |key, value| RubyProxyHeaders.validate_header!(key, value) } if https

        previous = Thread.current[:ruby_proxy_headers_rest_client_headers]
        Thread.current[:ruby_proxy_headers_rest_client_headers] = https ? headers : nil
        response = ::RestClient::Request.execute(execute_options(method, url, proxy, options))
        captured = RubyProxyHeaders.proxy_connect_response_headers
        ProxyResponse.new(response, captured ? captured.dup : HeaderMap.new)
      ensure
        Thread.current[:ruby_proxy_headers_rest_client_headers] = previous
      end

      # Patches Net::HTTP and RestClient::Request so proxy headers apply to outbound HTTPS.
      def install!
        RubyProxyHeaders::NetHTTP.patch!
        return if ::RestClient::Request.ancestors.include?(NetHttpHook)

        ::RestClient::Request.prepend(NetHttpHook)
      end

      private

      def execute_options(method, url, proxy, options)
        payload = options.key?(:payload) ? options[:payload] : options[:body]
        verify_ssl = options[:verify_ssl]
        verify_ssl = OpenSSL::SSL::VERIFY_PEER if verify_ssl == true
        verify_ssl = OpenSSL::SSL::VERIFY_NONE if verify_ssl == false
        {
          method: method,
          url: url,
          proxy: proxy,
          headers: options[:headers],
          payload: payload,
          open_timeout: options[:open_timeout],
          read_timeout: options[:read_timeout],
          verify_ssl: verify_ssl
        }.compact
      end
    end

    # RestClient response plus CONNECT response headers.
    class ProxyResponse < SimpleDelegator
      attr_reader :proxy_response_headers

      def initialize(response, proxy_headers)
        super(response)
        @proxy_response_headers = proxy_headers
      end
    end
  end
end
