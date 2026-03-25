# frozen_string_literal: true

require_relative 'ruby_proxy_headers/version'
require_relative 'ruby_proxy_headers/net_http'

module RubyProxyHeaders
  # CONNECT response headers from the last Net::HTTP-based proxied HTTPS request on this thread.
  def self.proxy_connect_response_headers
    Thread.current[:ruby_proxy_headers_connect_headers]
  end
end
