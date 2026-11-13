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
  # faraday-net_http 3.4 and 3.5 perform the request in the private method
  # +request_with_wrapped_block+. This adapter does not override that method.
  # It uses the public +build_connection+ and +call+ methods.
  module FaradayAdapter
    # Copies CONNECT response headers onto the Faraday response.
    class NetHttp < ::Faraday::Adapter::NetHttp
      def build_connection(env)
        super.tap { |http| Thread.current[:ruby_proxy_headers_faraday_http] = http }
      end

      def call(env)
        response = super
        http = Thread.current[:ruby_proxy_headers_faraday_http]
        headers = http.last_proxy_connect_response_headers if http
        if env[:response_headers] && headers
          headers.each do |key, value|
            next if value.nil?

            env[:response_headers][key] ||= value
          end
        end
        response
      ensure
        Thread.current[:ruby_proxy_headers_faraday_http] = nil
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
