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
  module FaradayAdapter
    class NetHttp < ::Faraday::Adapter::NetHttp
      def request_with_wrapped_block(http, env, &block)
        res = super
        merge_proxy_headers(env, http)
        res
      end

      private

      def merge_proxy_headers(env, http)
        return unless env[:response_headers]
        return unless http.respond_to?(:last_proxy_connect_response_headers)

        ph = http.last_proxy_connect_response_headers
        return unless ph.is_a?(Hash)

        ph.each do |k, v|
          next if v.nil?

          env[:response_headers][k] ||= v
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
