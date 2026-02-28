# frozen_string_literal: true

module RubyProxyHeaders
  # HTTParty integration for proxy headers support.
  # Include this module in your HTTParty-based class to add proxy header support.
  #
  # @example
  #   class ProxyClient
  #     include HTTParty
  #     include RubyProxyHeaders::HTTParty
  #     
  #     base_uri 'https://example.com'
  #     http_proxy 'proxy.example.com', 8080, 'user', 'pass'
  #     proxy_headers 'X-ProxyMesh-Country' => 'US'
  #   end
  #   
  #   response = ProxyClient.get('/')
  #   puts response.proxy_response_headers
  #
  module HTTParty
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Set proxy headers to send during CONNECT.
      # @param headers [Hash] Custom headers
      def proxy_headers(headers = nil)
        if headers
          @proxy_headers = headers
        else
          @proxy_headers || {}
        end
      end

      # Override get to use proxy headers
      def get(path, options = {}, &block)
        with_proxy_headers(options) do
          super
        end
      end

      # Override post to use proxy headers
      def post(path, options = {}, &block)
        with_proxy_headers(options) do
          super
        end
      end

      # Override put to use proxy headers
      def put(path, options = {}, &block)
        with_proxy_headers(options) do
          super
        end
      end

      # Override delete to use proxy headers
      def delete(path, options = {}, &block)
        with_proxy_headers(options) do
          super
        end
      end

      private

      def with_proxy_headers(options)
        # Merge class-level and request-level proxy headers
        headers = proxy_headers.merge(options.delete(:proxy_headers) || {})
        return yield if headers.empty?

        # Store for use in connection adapter
        Thread.current[:ruby_proxy_headers] = headers

        begin
          response = yield
          
          # Wrap response with proxy headers accessor
          if Thread.current[:ruby_proxy_response_headers]
            response.define_singleton_method(:proxy_response_headers) do
              Thread.current[:ruby_proxy_response_headers]
            end
          end

          response
        ensure
          Thread.current[:ruby_proxy_headers] = nil
        end
      end
    end

    # Standalone helper for making requests with proxy headers.
    # @param method [Symbol] HTTP method
    # @param url [String] Target URL
    # @param proxy [String] Proxy URL
    # @param proxy_headers [Hash] Custom headers to send to proxy
    # @param options [Hash] Additional request options
    # @return Response with proxy_response_headers accessor
    def self.request(method, url, proxy:, proxy_headers: {}, **options)
      require 'httparty'

      uri = URI.parse(url)

      # Use our custom connection for HTTPS with proxy
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

      # Fall back to standard HTTParty
      proxy_uri = URI.parse(proxy)
      httparty_options = options.merge(
        http_proxyaddr: proxy_uri.host,
        http_proxyport: proxy_uri.port,
        http_proxyuser: proxy_uri.user,
        http_proxypass: proxy_uri.password
      )

      ::HTTParty.send(method, url, httparty_options)
    end

    def self.get(url, proxy:, proxy_headers: {}, **options)
      request(:get, url, proxy: proxy, proxy_headers: proxy_headers, **options)
    end

    def self.post(url, proxy:, proxy_headers: {}, **options)
      request(:post, url, proxy: proxy, proxy_headers: proxy_headers, **options)
    end
  end
end
