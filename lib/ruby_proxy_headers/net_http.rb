# frozen_string_literal: true

require 'net/http'
require 'uri'

module RubyProxyHeaders
  # Extension module for Net::HTTP to support custom proxy headers.
  # Provides both a standalone client and a prepend module for patching Net::HTTP.
  module NetHTTP
    # Thread-local storage for proxy headers configuration
    def self.proxy_headers
      Thread.current[:ruby_proxy_headers_config] ||= {}
    end

    def self.proxy_headers=(headers)
      Thread.current[:ruby_proxy_headers_config] = headers
    end

    # Make a GET request with proxy header support.
    # @param url [String] Target URL
    # @param options [Hash] Request options
    # @option options [String] :proxy Proxy URL
    # @option options [Hash] :proxy_headers Custom headers to send to proxy
    # @option options [Hash] :headers Request headers
    # @option options [Integer] :open_timeout Connection timeout
    # @option options [Integer] :read_timeout Read timeout
    # @return [ProxyResponse] Response with proxy headers accessor
    def self.get(url, options = {})
      request(:get, url, options)
    end

    # Make a POST request with proxy header support.
    def self.post(url, body = nil, options = {})
      request(:post, url, options.merge(body: body))
    end

    # Make a request with proxy header support.
    # @param method [Symbol] HTTP method (:get, :post, :put, :delete, etc.)
    # @param url [String] Target URL
    # @param options [Hash] Request options
    # @return [ProxyResponse] Response with proxy headers accessor
    def self.request(method, url, options = {})
      uri = URI.parse(url)
      proxy_url = options[:proxy] || ENV['HTTPS_PROXY'] || ENV['HTTP_PROXY']
      proxy_headers = options[:proxy_headers] || {}

      unless proxy_url
        raise ArgumentError, 'Proxy URL required (pass :proxy option or set HTTPS_PROXY env var)'
      end

      # Create proxy connection
      connection = Connection.new(proxy_url, proxy_headers: proxy_headers)
      ssl_socket = connection.connect(uri.host, uri.port || 443)

      # Build and send HTTP request
      request_class = Net::HTTP.const_get(method.to_s.capitalize)
      http_request = request_class.new(uri)

      (options[:headers] || {}).each do |name, value|
        http_request[name] = value
      end

      if options[:body]
        http_request.body = options[:body]
      end

      # Use Net::HTTP for the actual request over the SSL socket
      http = Net::HTTP.new(uri.host, uri.port || 443)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      # We need to use the established socket
      response = send_request_over_socket(ssl_socket, http_request, uri)

      # Wrap response with proxy headers
      ProxyResponse.new(response, connection.proxy_response_headers)
    ensure
      connection&.close
    end

    # Send HTTP request over an established socket
    def self.send_request_over_socket(socket, request, uri)
      # Build request string
      request_line = "#{request.method} #{uri.request_uri} HTTP/1.1\r\n"
      headers = "Host: #{uri.host}\r\n"

      request.each_header do |name, value|
        headers << "#{name}: #{value}\r\n"
      end

      body = request.body || ''
      if body.length.positive?
        headers << "Content-Length: #{body.bytesize}\r\n"
      end

      headers << "Connection: close\r\n"
      headers << "\r\n"

      socket.write(request_line + headers + body)

      # Read response
      response_text = socket.read
      parse_http_response(response_text)
    end

    # Parse raw HTTP response into Net::HTTPResponse-like object
    def self.parse_http_response(response_text)
      lines = response_text.split("\r\n")
      status_line = lines.shift
      
      return nil if status_line.nil?

      match = status_line.match(%r{HTTP/[\d.]+\s+(\d+)\s*(.*)})
      return nil unless match

      code = match[1]
      message = match[2]

      headers = {}
      body_start = 0

      lines.each_with_index do |line, index|
        if line.empty?
          body_start = index + 1
          break
        end

        if (header_match = line.match(/^([^:]+):\s*(.*)$/))
          headers[header_match[1].downcase] = header_match[2]
        end
      end

      body = lines[body_start..].join("\r\n")

      # Handle chunked transfer encoding
      if headers['transfer-encoding'] == 'chunked'
        body = decode_chunked(body)
      end

      SimpleResponse.new(code.to_i, message, headers, body)
    end

    def self.decode_chunked(body)
      decoded = String.new
      remaining = body

      loop do
        break if remaining.empty?

        # Find chunk size
        size_end = remaining.index("\r\n")
        break unless size_end

        size_hex = remaining[0...size_end]
        size = size_hex.to_i(16)
        break if size.zero?

        # Extract chunk data
        chunk_start = size_end + 2
        chunk_end = chunk_start + size
        decoded << remaining[chunk_start...chunk_end]

        remaining = remaining[(chunk_end + 2)..]
      end

      decoded
    end

    # Simple response wrapper
    class SimpleResponse
      attr_reader :code, :message, :headers, :body

      def initialize(code, message, headers, body)
        @code = code
        @message = message
        @headers = headers
        @body = body
      end

      def [](header_name)
        @headers[header_name.downcase]
      end
    end

    # Response wrapper that includes proxy headers
    class ProxyResponse
      attr_reader :proxy_response_headers

      def initialize(response, proxy_headers)
        @response = response
        @proxy_response_headers = proxy_headers
      end

      def code
        @response.code
      end

      def body
        @response.body
      end

      def [](header_name)
        @response[header_name]
      end

      def headers
        @response.headers
      end

      def method_missing(method, *args, &block)
        @response.send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        @response.respond_to?(method, include_private) || super
      end
    end
  end
end
