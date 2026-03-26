# frozen_string_literal: true

begin
  require 'excon'
rescue LoadError => e
  raise LoadError, "excon is required for ruby_proxy_headers/excon (#{e.message})"
end

module RubyProxyHeaders
  # Excon already supports extra CONNECT headers via +:ssl_proxy_headers+ (see
  # Excon::SSLSocket). This module documents the mapping and a small helper.
  #
  # Reading CONNECT response headers is not exposed on Excon's public response
  # object for the origin request; use thread-local {RubyProxyHeaders.proxy_connect_response_headers}
  # only when the underlying transport is patched Net::HTTP, not Excon.
  module ExconIntegration
    module_function

    # @param proxy_url [String]
    # @param proxy_connect_headers [Hash] sent to the proxy during HTTPS CONNECT (Excon key: :ssl_proxy_headers)
    # @param excon_opts [Hash] merged into Excon.get / Excon.new options
    def get(url, proxy_url:, proxy_connect_headers: nil, **excon_opts)
      opts = {
        proxy: normalize_proxy_url(proxy_url),
        ssl_proxy_headers: proxy_connect_headers,
        ssl_verify_peer: true
      }.merge(excon_opts)
      Excon.get(url, opts)
    end

    def normalize_proxy_url(proxy_url)
      s = proxy_url.to_s.strip
      return s if s.match?(/\A[a-z][a-z0-9+\-.]*:\/\//i)

      "http://#{s}"
    end
  end
end
