# frozen_string_literal: true

require 'socket'
require 'openssl'
require 'uri'

module RubyProxyHeaders
  # Handles HTTPS CONNECT tunneling with custom proxy headers.
  # This is the core component that manages the proxy connection,
  # sends custom headers, and captures proxy response headers.
  class Connection
    attr_reader :proxy_response_headers, :proxy_response_status, :socket

    # @param proxy [String, Hash] Proxy URL or hash with :host, :port, :user, :password
    # @param options [Hash] Connection options
    # @option options [Hash] :proxy_headers Custom headers to send during CONNECT
    # @option options [Integer] :connect_timeout Connection timeout in seconds (default: 30)
    # @option options [Boolean] :verify_ssl Verify SSL certificates (default: true)
    def initialize(proxy, options = {})
      @proxy = proxy.is_a?(String) ? RubyProxyHeaders.parse_proxy_url(proxy) : proxy
      @proxy_headers = options[:proxy_headers] || {}
      @connect_timeout = options[:connect_timeout] || 30
      @verify_ssl = options.fetch(:verify_ssl, true)
      @proxy_response_headers = {}
      @proxy_response_status = nil
      @socket = nil
    end

    # Establish a tunnel through the proxy to the target host.
    # @param target_host [String] Target hostname
    # @param target_port [Integer] Target port (default: 443)
    # @return [OpenSSL::SSL::SSLSocket] TLS-wrapped socket to target
    def connect(target_host, target_port = 443)
      # Connect to proxy
      @socket = TCPSocket.new(@proxy[:host], @proxy[:port])
      @socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

      # Send CONNECT request with custom headers
      connect_request = build_connect_request(target_host, target_port)
      @socket.write(connect_request)

      # Read and parse CONNECT response
      response = read_connect_response
      parse_connect_response(response)

      # Check for successful connection
      unless (200..299).cover?(@proxy_response_status)
        @socket.close
        raise_connect_error
      end

      # Upgrade to TLS
      upgrade_to_tls(target_host)
    end

    # Close the connection
    def close
      @socket&.close
    end

    private

    def build_connect_request(target_host, target_port)
      request_lines = [
        "CONNECT #{target_host}:#{target_port} HTTP/1.1",
        "Host: #{target_host}:#{target_port}"
      ]

      # Add proxy authentication if provided
      if @proxy[:user]
        auth = RubyProxyHeaders.build_auth_header(@proxy[:user], @proxy[:password])
        request_lines << "Proxy-Authorization: #{auth}"
      end

      # Add custom proxy headers
      @proxy_headers.each do |name, value|
        request_lines << "#{name}: #{value}"
      end

      request_lines << 'Proxy-Connection: keep-alive'
      request_lines << ''
      request_lines << ''

      request_lines.join("\r\n")
    end

    def read_connect_response
      response = String.new
      loop do
        line = @socket.gets
        break if line.nil?

        response << line
        break if line == "\r\n" || line == "\n"
      end
      response
    end

    def parse_connect_response(response)
      lines = response.split(/\r?\n/)
      return if lines.empty?

      # Parse status line
      status_line = lines.shift
      if (match = status_line.match(%r{HTTP/[\d.]+\s+(\d+)}))
        @proxy_response_status = match[1].to_i
      end

      # Parse headers
      @proxy_response_headers = {}
      lines.each do |line|
        break if line.empty?

        if (header_match = line.match(/^([^:]+):\s*(.*)$/))
          name = header_match[1].downcase
          value = header_match[2]
          @proxy_response_headers[name] = value
        end
      end
    end

    def upgrade_to_tls(target_host)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.verify_mode = @verify_ssl ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE

      ssl_socket = OpenSSL::SSL::SSLSocket.new(@socket, ssl_context)
      ssl_socket.hostname = target_host
      ssl_socket.sync_close = true
      ssl_socket.connect

      @socket = ssl_socket
    end

    def raise_connect_error
      case @proxy_response_status
      when 407
        raise ProxyAuthenticationError, "Proxy authentication required (407)"
      else
        raise ConnectError, "Proxy CONNECT failed with status #{@proxy_response_status}"
      end
    end
  end
end
