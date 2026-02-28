# frozen_string_literal: true

module RubyProxyHeaders
  module Faraday
    # Faraday middleware for sending custom proxy headers during HTTPS CONNECT.
    # This middleware intercepts requests and uses the ProxyHeadersConnection
    # to establish the tunnel with custom headers.
    #
    # @example
    #   conn = Faraday.new(url: 'https://example.com') do |f|
    #     f.use RubyProxyHeaders::Faraday::Middleware,
    #           proxy: 'http://user:pass@proxy:8080',
    #           proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
    #     f.adapter Faraday.default_adapter
    #   end
    #   
    #   response = conn.get('/')
    #   puts response.env[:proxy_response_headers]
    #
    class Middleware
      def initialize(app, options = {})
        @app = app
        @proxy = options[:proxy]
        @proxy_headers = options[:proxy_headers] || {}
        @on_proxy_connect = options[:on_proxy_connect]
      end

      def call(env)
        # Only intercept HTTPS requests when proxy is configured
        if @proxy && env[:url].scheme == 'https'
          establish_proxy_tunnel(env)
        end

        @app.call(env).on_complete do |response_env|
          # Merge proxy response headers if available
          if env[:proxy_response_headers]
            response_env[:proxy_response_headers] = env[:proxy_response_headers]
          end
        end
      end

      private

      def establish_proxy_tunnel(env)
        connection = Connection.new(@proxy, proxy_headers: @proxy_headers)

        begin
          target_host = env[:url].host
          target_port = env[:url].port || 443

          connection.connect(target_host, target_port)

          # Store proxy response headers for later access
          env[:proxy_response_headers] = connection.proxy_response_headers

          # Call callback if provided
          @on_proxy_connect&.call(connection.proxy_response_headers)

          # Store connection for the adapter to use
          env[:proxy_ssl_socket] = connection.socket
        rescue StandardError
          connection.close
          raise
        end
      end
    end

    # Helper to create a Faraday connection with proxy header support.
    # @param url [String] Base URL for requests
    # @param proxy [String] Proxy URL
    # @param proxy_headers [Hash] Custom headers to send to proxy
    # @param options [Hash] Additional Faraday options
    # @return [Faraday::Connection]
    def self.create_connection(url, proxy:, proxy_headers: {}, **options)
      require 'faraday'

      ::Faraday.new(url: url, **options) do |f|
        f.use Middleware, proxy: proxy, proxy_headers: proxy_headers
        f.adapter ::Faraday.default_adapter
      end
    end
  end
end
