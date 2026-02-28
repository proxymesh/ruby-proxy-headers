# frozen_string_literal: true

module RubyProxyHeaders
  # HTTP.rb (http gem) integration for proxy headers support.
  #
  # @example
  #   client = RubyProxyHeaders::HTTPGem.create_client(
  #     proxy: 'http://user:pass@proxy:8080',
  #     proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  #   )
  #   
  #   response = client.get('https://example.com')
  #   puts response.proxy_response_headers
  #
  module HTTPGem
    # Create an HTTP client with proxy header support.
    # @param proxy [String] Proxy URL
    # @param proxy_headers [Hash] Custom headers to send to proxy
    # @param options [Hash] Additional HTTP.rb options
    # @return [ProxyClient]
    def self.create_client(proxy:, proxy_headers: {}, **options)
      ProxyClient.new(proxy: proxy, proxy_headers: proxy_headers, **options)
    end

    # Make a GET request with proxy headers.
    def self.get(url, proxy:, proxy_headers: {}, **options)
      create_client(proxy: proxy, proxy_headers: proxy_headers).get(url, **options)
    end

    # Make a POST request with proxy headers.
    def self.post(url, proxy:, proxy_headers: {}, body: nil, **options)
      create_client(proxy: proxy, proxy_headers: proxy_headers).post(url, body: body, **options)
    end

    # Proxy client wrapper for HTTP.rb
    class ProxyClient
      def initialize(proxy:, proxy_headers: {}, **options)
        @proxy = proxy
        @proxy_headers = proxy_headers
        @options = options
        @last_proxy_response_headers = nil
      end

      attr_reader :last_proxy_response_headers

      def get(url, **options)
        request(:get, url, **options)
      end

      def post(url, body: nil, **options)
        request(:post, url, body: body, **options)
      end

      def put(url, body: nil, **options)
        request(:put, url, body: body, **options)
      end

      def delete(url, **options)
        request(:delete, url, **options)
      end

      private

      def request(method, url, **options)
        uri = URI.parse(url)

        # Use our core connection for HTTPS
        if uri.scheme == 'https'
          response = RubyProxyHeaders::NetHTTP.request(
            method,
            url,
            proxy: @proxy,
            proxy_headers: @proxy_headers,
            headers: options[:headers],
            body: options[:body]
          )
          @last_proxy_response_headers = response.proxy_response_headers
          return response
        end

        # For HTTP, use standard http gem
        require 'http'

        proxy_uri = URI.parse(@proxy)
        ::HTTP.via(
          proxy_uri.host,
          proxy_uri.port,
          proxy_uri.user,
          proxy_uri.password
        ).send(method, url, **options)
      end
    end
  end
end
