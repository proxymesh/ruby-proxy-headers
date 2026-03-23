# frozen_string_literal: true

require 'net/http'
require 'net/protocol'
require 'openssl'
require 'resolv'
require 'timeout'

module RubyProxyHeaders
  # Patches Net::HTTP#connect for HTTPS-over-proxy so extra headers can be sent on
  # the CONNECT request and response headers can be read (e.g. ProxyMesh
  # X-ProxyMesh-IP). Based on the same tunnel flow as Python's http.client / urllib3
  # extensions in python-proxy-headers.
  #
  # @example
  #   require 'ruby_proxy_headers/net_http'
  #   RubyProxyHeaders::NetHTTP.patch!
  #
  #   http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
  #   http.use_ssl = true
  #   http.proxy_connect_request_headers = { 'X-ProxyMesh-IP' => '203.0.113.1' }
  #   res = http.request(Net::HTTP::Get.new(uri))
  #   p http.last_proxy_connect_response_headers
  module NetHTTP
    unless const_defined?(:ORIGINAL_CONNECT, false)
      ORIGINAL_CONNECT = ::Net::HTTP.instance_method(:connect)
    end

    module Extension
      attr_accessor :proxy_connect_request_headers
      attr_reader :last_proxy_connect_response_headers

      def connect
        if use_ssl? && proxy?
          connect_with_proxy_tunnel
        else
          RubyProxyHeaders::NetHTTP::ORIGINAL_CONNECT.bind_call(self)
        end
      end

      private

      # Duplicates Net::HTTP#connect (MRI 3.2) for the HTTPS + proxy branch, with
      # optional extra CONNECT headers and capture of the CONNECT response headers.
      def connect_with_proxy_tunnel
        s = nil
        if use_ssl?
          @ssl_context = OpenSSL::SSL::SSLContext.new
        end

        if proxy?
          conn_addr = proxy_address
          conn_port = proxy_port
        else
          conn_addr = conn_address
          conn_port = port
        end

        debug "opening connection to #{conn_addr}:#{conn_port}..."
        s = Timeout.timeout(@open_timeout, Net::OpenTimeout) do
          begin
            TCPSocket.open(conn_addr, conn_port, @local_host, @local_port)
          rescue StandardError => e
            raise e, "Failed to open TCP connection to " \
              "#{conn_addr}:#{conn_port} (#{e.message})"
          end
        end
        s.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        debug 'opened'

        if use_ssl?
          if proxy?
            plain_sock = Net::BufferedIO.new(s, read_timeout: @read_timeout,
                                            write_timeout: @write_timeout,
                                            continue_timeout: @continue_timeout,
                                            debug_output: @debug_output)
            buf = +"CONNECT #{conn_address}:#{@port} HTTP/#{::Net::HTTP::HTTPVersion}\r\n" \
              "Host: #{@address}:#{@port}\r\n"
            if proxy_user
              credential = ["#{proxy_user}:#{proxy_pass}"].pack('m0')
              buf << "Proxy-Authorization: Basic #{credential}\r\n"
            end
            if proxy_connect_request_headers&.any?
              proxy_connect_request_headers.each do |k, v|
                buf << "#{k}: #{v}\r\n"
              end
            end
            buf << "\r\n"
            plain_sock.write(buf)

            proxy_res = ::Net::HTTPResponse.read_new(plain_sock)
            @last_proxy_connect_response_headers = {}
            proxy_res.each_header do |k, v|
              @last_proxy_connect_response_headers[k] = v
            end
            proxy_res.value
          end

          ssl_parameters = {}
          iv_list = instance_variables
          Net::HTTP::SSL_IVNAMES.each_with_index do |ivname, i|
            if iv_list.include?(ivname)
              value = instance_variable_get(ivname)
              unless value.nil?
                ssl_parameters[Net::HTTP::SSL_ATTRIBUTES[i]] = value
              end
            end
          end
          @ssl_context.set_params(ssl_parameters)
          unless @ssl_context.session_cache_mode.nil?
            @ssl_context.session_cache_mode =
              OpenSSL::SSL::SSLContext::SESSION_CACHE_CLIENT |
              OpenSSL::SSL::SSLContext::SESSION_CACHE_NO_INTERNAL_STORE
          end
          if @ssl_context.respond_to?(:session_new_cb)
            @ssl_context.session_new_cb = proc { |sock, sess| @ssl_session = sess }
          end

          verify_hostname = @ssl_context.verify_hostname

          case @address
          when Resolv::IPv4::Regex, Resolv::IPv6::Regex
            @ssl_context.verify_hostname = false
          else
            ssl_host_address = @address
          end

          debug "starting SSL for #{conn_addr}:#{conn_port}..."
          s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
          s.sync_close = true
          s.hostname = ssl_host_address if s.respond_to?(:hostname=) && ssl_host_address

          if @ssl_session &&
             Process.clock_gettime(Process::CLOCK_REALTIME) < @ssl_session.time.to_f + @ssl_session.timeout
            s.session = @ssl_session
          end
          ssl_socket_connect(s, @open_timeout)
          if (@ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE) && verify_hostname
            s.post_connection_check(@address)
          end
          debug "SSL established, protocol: #{s.ssl_version}, cipher: #{s.cipher[0]}"
        end
        @socket = Net::BufferedIO.new(s, read_timeout: @read_timeout,
                                     write_timeout: @write_timeout,
                                     continue_timeout: @continue_timeout,
                                     debug_output: @debug_output)
        @last_communicated = nil
        on_connect
      rescue StandardError => e
        if s
          debug "Conn close because of connect error #{e}"
          s.close
        end
        raise
      end
    end

    class << self
      def patch!
        return if @patched

        ::Net::HTTP.prepend(Extension)
        @patched = true
      end

      def patched?
        @patched == true
      end
    end
  end
end
