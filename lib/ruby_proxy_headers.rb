# frozen_string_literal: true

require_relative 'ruby_proxy_headers/version'
require_relative 'ruby_proxy_headers/net_http'

module RubyProxyHeaders
  INVALID_HEADER_NAME_RE = /[\r\n\0]/
  INVALID_HEADER_VALUE_RE = /[\r\n\0]/

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
    if INVALID_HEADER_VALUE_RE.match?(value.to_s)
      raise ArgumentError, "proxy CONNECT header value contains invalid characters (CR, LF, or NUL): #{value.inspect}"
    end
  end

  # Raises ArgumentError if +host+ or +port+ contain CR, LF, or NUL bytes that
  # would allow HTTP request smuggling when interpolated into a CONNECT line.
  def self.validate_connect_target!(host, port)
    if INVALID_HEADER_VALUE_RE.match?(host.to_s)
      raise ArgumentError,
            "CONNECT target host contains invalid characters (CR, LF, or NUL): #{host.inspect}"
    end
    if INVALID_HEADER_VALUE_RE.match?(port.to_s)
      raise ArgumentError,
            "CONNECT target port contains invalid characters (CR, LF, or NUL): #{port.inspect}"
    end
  end
end
