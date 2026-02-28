# frozen_string_literal: true

module RubyProxyHeaders
  # RestClient integration for proxy headers support.
  #
  # @example
  #   response = RubyProxyHeaders::RestClient.get(
  #     'https://example.com',
  #     proxy: 'http://user:pass@proxy:8080',
  #     proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  #   )
  #   puts response.proxy_response_headers
  #
  module RestClient
    # Make a GET request with proxy headers.
    def self.get(url, proxy:, proxy_headers: {}, **options)
      request(:get, url, proxy: proxy, proxy_headers: proxy_headers, **options)
    end

    # Make a POST request with proxy headers.
    def self.post(url, proxy:, proxy_headers: {}, payload: nil, **options)
      request(:post, url, proxy: proxy, proxy_headers: proxy_headers, body: payload, **options)
    end

    # Make a PUT request with proxy headers.
    def self.put(url, proxy:, proxy_headers: {}, payload: nil, **options)
      request(:put, url, proxy: proxy, proxy_headers: proxy_headers, body: payload, **options)
    end

    # Make a DELETE request with proxy headers.
    def self.delete(url, proxy:, proxy_headers: {}, **options)
      request(:delete, url, proxy: proxy, proxy_headers: proxy_headers, **options)
    end

    # Make a request with proxy headers.
    def self.request(method, url, proxy:, proxy_headers: {}, **options)
      require 'rest-client'

      uri = URI.parse(url)

      # For HTTPS with proxy headers, use our core connection
      if uri.scheme == 'https' && !proxy_headers.empty?
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

      # For HTTP or no proxy headers, use standard RestClient
      ::RestClient.proxy = proxy
      response = ::RestClient.send(method, url, options)
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

      def method_missing(method, *args, &block)
        @response.send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        @response.respond_to?(method, include_private) || super
      end
    end
  end
end
