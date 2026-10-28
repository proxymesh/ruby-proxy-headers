# frozen_string_literal: true

require 'openssl'
require 'socket'

# Local HTTP proxy plus TLS origin used to observe CONNECT bytes.
# The proxy records the CONNECT request and answers with X-ProxyMesh-IP,
# then splices the tunnel to the origin. The origin records the HTTP request
# that arrived inside TLS.
module TyphoeusConnectLab
  class Origin
    attr_reader :port, :request, :error

    def initialize
      @request = nil
      @error = nil
      @tcp = TCPServer.new('127.0.0.1', 0)
      @port = @tcp.addr[1]
      cert, key = self.class.certificate
      context = OpenSSL::SSL::SSLContext.new
      context.cert = cert
      context.key = key
      context.verify_mode = OpenSSL::SSL::VERIFY_NONE
      @ssl = OpenSSL::SSL::SSLServer.new(@tcp, context)
      @thread = Thread.new { accept_loop }
    end

    def stop
      @tcp.close
      @thread.join(2)
    end

    def self.certificate
      key = OpenSSL::PKey::EC.generate('prime256v1')
      name = OpenSSL::X509::Name.parse('/CN=127.0.0.1')
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 1
      cert.subject = name
      cert.issuer = name
      cert.public_key = key
      now = Time.now
      cert.not_before = now - 60
      cert.not_after = now + 3600
      factory = OpenSSL::X509::ExtensionFactory.new
      factory.subject_certificate = cert
      factory.issuer_certificate = cert
      cert.add_extension(factory.create_extension('basicConstraints', 'CA:FALSE', true))
      cert.add_extension(factory.create_extension('subjectAltName', 'IP:127.0.0.1', false))
      cert.sign(key, OpenSSL::Digest.new('SHA256'))
      [cert, key]
    end

    private

    def accept_loop
      loop do
        client = @ssl.accept
        handle(client)
      end
    rescue IOError, Errno::EBADF, OpenSSL::SSL::SSLError
      nil
    rescue StandardError => e
      @error = e
    end

    def handle(client)
      data = +''
      data << client.readpartial(4096) until data.include?("\r\n\r\n")
      @request = data
      body = 'origin-ok'
      client.write(
        "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n" \
        "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
      )
    ensure
      client&.close
    end
  end

  class Proxy
    attr_reader :port, :connect_request, :error

    def initialize
      @connect_request = nil
      @error = nil
      @tcp = TCPServer.new('127.0.0.1', 0)
      @port = @tcp.addr[1]
      @thread = Thread.new { accept_loop }
    end

    def stop
      @tcp.close
      @thread.join(2)
    end

    private

    def accept_loop
      loop do
        client = @tcp.accept
        handle(client)
      end
    rescue IOError, Errno::EBADF
      nil
    rescue StandardError => e
      @error = e
    end

    def handle(client)
      upstream = nil
      head, rest = read_head(client)
      @connect_request = head
      client.write(
        "HTTP/1.1 200 Connection established\r\nX-ProxyMesh-IP: 203.0.113.10\r\n\r\n"
      )
      host, port = connect_target(head)
      upstream = TCPSocket.new(host, port)
      upstream.write(rest) unless rest.empty?
      splice(client, upstream)
    ensure
      upstream&.close
      client&.close
    end

    def read_head(sock)
      data = +''
      data << sock.readpartial(1024) until data.include?("\r\n\r\n")
      head, rest = data.split("\r\n\r\n", 2)
      [head, rest.to_s]
    end

    def connect_target(head)
      target = head.lines.first.to_s.split[1].to_s
      host, _, port = target.rpartition(':')
      [host, Integer(port)]
    end

    def splice(left, right)
      threads = [Thread.new { copy(left, right) }, Thread.new { copy(right, left) }]
      threads.each do |thread|
        thread.join
      rescue StandardError
        nil
      end
    end

    def copy(src, dst)
      IO.copy_stream(src, dst)
    rescue IOError, SystemCallError
      nil
    ensure
      close_quietly(dst)
    end

    def close_quietly(io)
      io.close
    rescue IOError, SystemCallError
      nil
    end
  end
end
