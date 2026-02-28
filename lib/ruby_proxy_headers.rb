# frozen_string_literal: true

require_relative 'ruby_proxy_headers/version'
require_relative 'ruby_proxy_headers/connection'
require_relative 'ruby_proxy_headers/net_http'

module RubyProxyHeaders
  class Error < StandardError; end
  class ConnectError < Error; end
  class ProxyAuthenticationError < ConnectError; end

  class << self
    # Parse a proxy URL into components
    # @param url [String] Proxy URL (e.g., http://user:pass@proxy:8080)
    # @return [Hash] Parsed components
    def parse_proxy_url(url)
      uri = URI.parse(url)
      {
        host: uri.host,
        port: uri.port || 8080,
        user: uri.user,
        password: uri.password,
        scheme: uri.scheme || 'http'
      }
    end

    # Build Basic auth header value
    # @param user [String] Username
    # @param password [String] Password
    # @return [String] Base64-encoded auth string
    def build_auth_header(user, password)
      require 'base64'
      "Basic #{Base64.strict_encode64("#{user}:#{password}")}"
    end
  end
end

# Autoload optional integrations
module RubyProxyHeaders
  autoload :Faraday, 'ruby_proxy_headers/faraday'
  autoload :HTTParty, 'ruby_proxy_headers/httparty'
  autoload :HTTPGem, 'ruby_proxy_headers/http_gem'
  autoload :Typhoeus, 'ruby_proxy_headers/typhoeus'
  autoload :Excon, 'ruby_proxy_headers/excon'
  autoload :RestClient, 'ruby_proxy_headers/rest_client'
end
