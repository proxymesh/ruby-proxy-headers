# frozen_string_literal: true

require_relative 'net_http'

begin
  require 'faraday'
  require 'faraday/net_http'
rescue LoadError => e
  raise LoadError,
        'faraday and faraday-net_http are required for ruby_proxy_headers/faraday ' \
        "(#{e.message})"
end

module RubyProxyHeaders
  # Faraday adapter that merges proxy CONNECT response headers into Faraday response headers.
  # Use with {RubyProxyHeaders::NetHTTP.patch!}.
  #
  # faraday-net_http 3.4+ implements the request on the private method
  # +request_with_wrapped_block+. This adapter does not override that method.
  # It uses the public +net_http_connection+ and +call+ hooks so a rename of the
  # private method still leaves CONNECT response headers on the Faraday response.
  module FaradayAdapter
    class NetHttp < ::Faraday::Adapter::NetHttp
      def net_http_connection(env)
        super.tap { |http| faraday_http_stack << http }
      end

      def call(env)
        depth = faraday_http_stack.size
        response = super
        http = faraday_http_stack.last if faraday_http_stack.size > depth
        merge_proxy_headers(env, http)
        response
      ensure
        pop_faraday_http_stack(depth)
      end

      private

      def faraday_http_stack
        Thread.current[:ruby_proxy_headers_faraday_stack] ||= []
      end

      def pop_faraday_http_stack(depth)
        return if depth.nil?

        stack = faraday_http_stack
        stack.pop while stack.size > depth
      end

      def merge_proxy_headers(env, http)
        return unless env.respond_to?(:[]) && env[:response_headers]
        return unless http.respond_to?(:last_proxy_connect_response_headers)

        proxy_headers = http.last_proxy_connect_response_headers
        return unless proxy_headers.respond_to?(:each)

        proxy_headers.each do |key, value|
          next if value.nil?

          env[:response_headers][key] ||= value
        end
      end
    end
  end
end

Faraday::Adapter.register_middleware(
  ruby_proxy_headers_net_http: RubyProxyHeaders::FaradayAdapter::NetHttp
)

module RubyProxyHeaders
  module FaradayIntegration
    module_function

    def patch!
      RubyProxyHeaders::NetHTTP.patch!
    end

    # Builds a Faraday connection with the custom Net::HTTP adapter and optional CONNECT headers.
    #
    # @param proxy [String] proxy URL
    # @param proxy_connect_headers [Hash, nil] headers to send on CONNECT (e.g. X-ProxyMesh-IP)
    # @param url [String, nil] optional base URL
    def connection(proxy:, proxy_connect_headers: nil, url: nil, &block)
      patch!
      opts = { proxy: proxy }
      opts[:url] = url if url
      ::Faraday.new(opts) do |f|
        f.adapter :ruby_proxy_headers_net_http do |http|
          http.proxy_connect_request_headers = proxy_connect_headers if proxy_connect_headers&.any?
        end
        yield f if block_given?
      end
    end
  end
end
