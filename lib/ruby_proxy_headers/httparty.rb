# frozen_string_literal: true

require_relative 'net_http'

begin
  require 'httparty'
rescue LoadError => e
  raise LoadError, "httparty is required for ruby_proxy_headers/httparty (#{e.message})"
end

module RubyProxyHeaders
  # Drop-in connection adapter: pass +:proxy_connect_request_headers+ in options
  # (along with +http_proxyaddr+ / +http_proxyport+ / etc.).
  #
  # After the request, read CONNECT response headers via
  # {RubyProxyHeaders.proxy_connect_response_headers} (thread-local).
  class ProxyHeadersConnectionAdapter < HTTParty::ConnectionAdapter
    def connection
      http = super
      if http.respond_to?(:proxy_connect_request_headers=)
        h = options[:proxy_connect_request_headers] || options[:proxy_connect_headers]
        http.proxy_connect_request_headers = h if h&.any?
      end
      http
    end
  end
end
