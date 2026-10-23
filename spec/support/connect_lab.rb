# frozen_string_literal: true

require 'openssl'
require 'socket'
require 'tempfile'
require 'timeout'

module ConnectLab
  module_function

  def self_signed_cert
    key = OpenSSL::PKey::EC.generate('prime256v1')
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 1
    cert.subject = cert.issuer = OpenSSL::X509::Name.parse('CN=127.0.0.1')
    cert.not_before = Time.now - 3600
    cert.not_after = Time.now + 86_400
    cert.public_key = key
    factory = OpenSSL::X509::ExtensionFactory.new
    factory.subject_certificate = cert
    factory.issuer_certificate = cert
    cert.add_extension(factory.create_extension('basicConstraints', 'CA:FALSE', true))
    cert.add_extension(factory.create_extension('subjectAltName', 'IP:127.0.0.1,DNS:localhost', false))
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    [cert, key]
  end

  def server_context
    cert, key = self_signed_cert
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.cert = cert
    ctx.key = key
    ctx
  end

  # Minimal HTTPS origin. Records the cleartext HTTP request that arrived
  # through the tunnel and answers with a fixed body.
  class HttpsOrigin
    attr_reader :port, :requests

    def initialize
      @requests = Queue.new
      @ctx = ConnectLab.server_context
      @tcp = TCPServer.new('127.0.0.1', 0)
      @port = @tcp.addr[1]
      @accept = Thread.new { accept_loop }
      @accept.abort_on_exception = false
    end

    def close
      @tcp.close rescue nil
      @accept.kill rescue nil
    end

    private

    def accept_loop
      loop do
        client = @tcp.accept
        Thread.new { handle(client) }
      end
    rescue IOError, Errno::EBADF
      nil
    end

    def handle(client)
      ssl = OpenSSL::SSL::SSLSocket.new(client, @ctx)
      ssl.sync_close = true
      ssl.accept
      request = +''
      while (line = ssl.gets)
        request << line
        break if line == "\r\n" || line == "\n"
      end
      @requests << request
      body = '{"via":"local-https"}'
      ssl.write(
        "HTTP/1.1 200 OK\r\n" \
        "Content-Type: application/json\r\n" \
        "Content-Length: #{body.bytesize}\r\n" \
        "Connection: close\r\n\r\n#{body}"
      )
      ssl.close
    rescue IOError, Errno::ECONNRESET, Errno::EPIPE, OpenSSL::SSL::SSLError
      nil
    end
  end

  # HTTPS proxy: TLS first, then CONNECT, then a raw byte pipe to the target.
  #
  # net-http's +proxy_use_ssl+ speaks TLS only for the proxy handshake and the
  # CONNECT request. The origin handshake is started on the underlying TCP
  # socket (ruby/net-http#212), so bytes after the CONNECT response must be
  # forwarded undecrypted.
  class TlsProxy
    attr_reader :port, :connect_heads, :first_bytes

    def initialize
      @connect_heads = Queue.new
      @first_bytes = Queue.new
      @ctx = ConnectLab.server_context
      @tcp = TCPServer.new('127.0.0.1', 0)
      @port = @tcp.addr[1]
      @accept = Thread.new { accept_loop }
    end

    def close
      @tcp.close rescue nil
      @accept.kill rescue nil
    end

    private

    def accept_loop
      loop do
        client = @tcp.accept
        Thread.new { handle(client) }
      end
    rescue IOError, Errno::EBADF
      nil
    end

    def handle(client)
      client.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      peeked = client.recv(5, Socket::MSG_PEEK)
      @first_bytes << peeked
      ssl = OpenSSL::SSL::SSLSocket.new(client, @ctx)
      ssl.sync_close = false
      ssl.sync = true
      ssl.accept
      head = +''
      while (line = ssl.gets)
        head << line
        break if line == "\r\n" || line == "\n"
      end
      @connect_heads << head
      target = head.lines.first.to_s.split[1]
      host, port = target.rpartition(':').values_at(0, 2)
      upstream = TCPSocket.new(host, port.to_i)
      upstream.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      ssl.write(
        "HTTP/1.1 200 Connection established\r\n" \
        "X-ProxyMesh-IP: 203.0.113.9\r\n\r\n"
      )
      pump(client, upstream)
    rescue StandardError
      client.close rescue nil
    end

    def pump(left, right)
      [left, right].permutation(2).each do |src, dst|
        Thread.new do
          loop { dst.write(src.readpartial(16_384)) }
        rescue EOFError, IOError, Errno::ECONNRESET, Errno::EPIPE, OpenSSL::SSL::SSLError
          begin
            dst.close_write
          rescue IOError, Errno::ENOTCONN
            nil
          end
        end
      end
    end
  end

  class MockProxy
    attr_reader :port, :pid

    def self.start
      script = File.expand_path('../../test/mock_connect_proxy.py', __dir__)
      log = Tempfile.new('mock-connect-proxy')
      port = reserve_port
      pid = Process.spawn('python3', script, port.to_s, out: log.path, err: log.path, pgroup: true)
      proxy = new(port, pid, log)
      proxy.wait_until_listening
      proxy
    end

    def initialize(port, pid, log)
      @port = port
      @pid = pid
      @log = log
    end

    def stop
      Process.kill('TERM', -pid) rescue nil
      Process.wait(pid) rescue nil
      @log.close rescue nil
    end

    def log_text
      File.read(@log.path)
    rescue Errno::ENOENT
      ''
    end

    def wait_until_listening
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
      loop do
        TCPSocket.new('127.0.0.1', port).close
        return
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET
        raise "mock proxy did not listen on #{port}: #{log_text}" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

        sleep 0.05
      end
    end

    def self.reserve_port
      server = TCPServer.new('127.0.0.1', 0)
      server.addr[1]
    ensure
      server&.close
    end
  end

  def header(headers, name)
    return nil unless headers.respond_to?(:[])

    return headers[name] if headers[name]

    key = headers.keys.find { |candidate| candidate.to_s.casecmp(name).zero? }
    key ? headers[key] : nil
  end
end
