# frozen_string_literal: true

module RubyProxyHeaders
  # Excon integration for proxy headers support.
  #
  # @example
  #   response = RubyProxyHeaders::Excon.get(
  #     'https://example.com',
  #     proxy: 'http://user:pass@proxy:8080',
  #     proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  #   )
  #   puts response.proxy_response_headers
  #
  module Excon
    # Make a GET request with proxy headers.
    def self.get(url, proxy:, proxy_headers: {}, **options)
      request(:get, url, proxy: proxy, proxy_headers: proxy_headers, **options)
    end

    # Make a POST request with proxy headers.
    def self.post(url, proxy:, proxy_headers: {}, body: nil, **options)
      request(:post, url, proxy: proxy, proxy_headers: proxy_headers, body: body, **options)
    end

    # Make a request with proxy headers.
    def self.request(method, url, proxy:, proxy_headers: {}, **options)
      require 'excon'

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

      # For HTTP or no proxy headers, use standard Excon
      excon_options = options.merge(
        proxy: proxy,
        method: method
      )

      response = ::Excon.new(url, excon_options).request(method: method)
      ProxyResponse.new(response, {})
    end

    # Response wrapper with proxy headers accessor
    class ProxyResponse
      attr_reader :proxy_response_headers

      def initialize(response, proxy_headers)
        @response = response
        @proxy_response_headers = proxy_headers
      end

      def status
        @response.status
      end
      alias code status

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
