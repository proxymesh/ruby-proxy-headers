# frozen_string_literal: true

require_relative 'ruby_proxy_headers/version'
require_relative 'ruby_proxy_headers/net_http'

# Helpers for sending custom proxy headers on HTTPS CONNECT and reading proxy response headers back.
module RubyProxyHeaders
  # Rejects proxy header names that contain CR, LF, or NUL (header injection).
  INVALID_HEADER_NAME_RE = /[\r\n\0]/
  # Rejects proxy header values that contain CR, LF, or NUL (header injection).
  INVALID_HEADER_VALUE_RE = /[\r\n\0]/

  # HTTP header map with case-insensitive lookup. Names are stored downcased,
  # which is how Net::HTTP yields them. +X-ProxyMesh-IP+ and +x-proxymesh-ip+
  # read the same value. +[]+, +[]=+, +fetch+, +delete+, and +key?+ normalize
  # names. Other Hash methods still use the stored downcased key.
  class HeaderMap < Hash
    # Case-insensitive lookup for a proxy response header name.
    def [](key)
      super(normalize(key))
    end

    # Stores a proxy response header under a normalized (downcased) name.
    def []=(key, value)
      super(normalize(key), value)
    end

    # Fetches a proxy response header value with optional default, using case-insensitive names.
    def fetch(key, *args, &block)
      super(normalize(key), *args, &block)
    end

    # Removes a proxy response header by case-insensitive name.
    def delete(key)
      super(normalize(key))
    end

    def key?(key)
      super(normalize(key))
    end

    private

    def normalize(key)
      key.to_s.downcase
    end
  end

  # CONNECT response headers from the last Net::HTTP-based proxied HTTPS request on this thread.
  def self.proxy_connect_response_headers
    Thread.current[:ruby_proxy_headers_connect_headers]
  end

  # Raises ArgumentError if +name+ or +value+ contain CR, LF, or NUL bytes
  # that would allow HTTP header injection in a raw CONNECT request.
  def self.validate_header!(name, value)
    if INVALID_HEADER_NAME_RE.match?(name.to_s)
      raise ArgumentError, "proxy CONNECT header name contains invalid characters (CR, LF, or NUL): #{name.inspect}"
    end
    return unless INVALID_HEADER_VALUE_RE.match?(value.to_s)

    raise ArgumentError, "proxy CONNECT header value contains invalid characters (CR, LF, or NUL): #{value.inspect}"
  end

  # Raises ArgumentError if +host+ or +port+ contain CR, LF, or NUL bytes that
  # would allow HTTP request smuggling when interpolated into a CONNECT line.
  def self.validate_connect_target!(host, port)
    if INVALID_HEADER_VALUE_RE.match?(host.to_s)
      raise ArgumentError,
            "CONNECT target host contains invalid characters (CR, LF, or NUL): #{host.inspect}"
    end
    return unless INVALID_HEADER_VALUE_RE.match?(port.to_s)

    raise ArgumentError,
          "CONNECT target port contains invalid characters (CR, LF, or NUL): #{port.inspect}"
  end
end
