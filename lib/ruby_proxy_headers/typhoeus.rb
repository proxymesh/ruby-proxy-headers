# frozen_string_literal: true

module RubyProxyHeaders
  # Typhoeus/Ethon integration for proxy headers support.
  # Typhoeus wraps libcurl, which has native support for CURLOPT_PROXYHEADER.
  #
  # @example
  #   response = RubyProxyHeaders::Typhoeus.get(
  #     'https://example.com',
  #     proxy: 'http://user:pass@proxy:8080',
  #     proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  #   )
  #   puts response.proxy_response_headers
  #
  module Typhoeus
    # Make a GET request with proxy headers.
    # @param url [String] Target URL
    # @param proxy [String] Proxy URL
    # @param proxy_headers [Hash] Custom headers to send to proxy
    # @param options [Hash] Additional Typhoeus options
    # @return [ProxyResponse]
    def self.get(url, proxy:, proxy_headers: {}, **options)
      request(:get, url, proxy: proxy, proxy_headers: proxy_headers, **options)
    end

    # Make a POST request with proxy headers.
    def self.post(url, proxy:, proxy_headers: {}, body: nil, **options)
      request(:post, url, proxy: proxy, proxy_headers: proxy_headers, body: body, **options)
    end

    # Make a request with proxy headers.
    # @param method [Symbol] HTTP method
    # @param url [String] Target URL
    # @param proxy [String] Proxy URL
    # @param proxy_headers [Hash] Custom headers to send to proxy
    # @param options [Hash] Additional Typhoeus options
    # @return [ProxyResponse]
    def self.request(method, url, proxy:, proxy_headers: {}, **options)
      require 'typhoeus'

      uri = URI.parse(url)

      # For HTTPS, we need custom handling since Typhoeus doesn't expose CURLOPT_PROXYHEADER
      if uri.scheme == 'https' && !proxy_headers.empty?
        # Use our core connection for now
        # TODO: Extend Ethon to expose CURLOPT_PROXYHEADER for native support
        response = RubyProxyHeaders::NetHTTP.request(
          method,
          url,
          proxy: proxy,
          proxy_headers: proxy_headers,
          headers: options[:headers],
          body: options[:body]
        )
        return response
      end

      # For HTTP or no proxy headers, use standard Typhoeus
      typhoeus_options = options.merge(
        proxy: proxy,
        method: method
      )

      response = ::Typhoeus::Request.new(url, typhoeus_options).run
      ProxyResponse.new(response, {})
    end

    # Response wrapper with proxy headers accessor
    class ProxyResponse
      attr_reader :proxy_response_headers

      def initialize(response, proxy_headers)
        @response = response
        @proxy_response_headers = proxy_headers
      end

      def code
        @response.code
      end

      def body
        @response.body
      end

      def headers
        @response.headers
      end

      def success?
        @response.success?
      end

      def method_missing(method, *args, &block)
        @response.send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        @response.respond_to?(method, include_private) || super
      end
    end
  end
end
