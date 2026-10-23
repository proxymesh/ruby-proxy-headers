# frozen_string_literal: true

require 'socket'
require 'timeout'

root = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(root, 'lib')) unless $LOAD_PATH.include?(File.join(root, 'lib'))
require 'ruby_proxy_headers'
require_relative 'support/connect_lab'

# Exercises the installed net-http, including versions older than the lockfile.
# Run across versions with gemfiles/net_http_matrix.gemfile.
RSpec.describe 'net-http CONNECT compatibility' do
  before do
    WebMock.disable! if defined?(WebMock)
    RubyProxyHeaders::NetHTTP.patch!
  end

  after do
    if defined?(WebMock)
      WebMock.enable!
      WebMock.disable_net_connect!
    end
  end

  def net_http_version
    return ::Net::HTTP::VERSION if defined?(::Net::HTTP::VERSION)

    spec = Gem.loaded_specs['net-http']
    spec ? spec.version.to_s : 'default'
  end

  it "round-trips a custom CONNECT header on net-http #{defined?(::Net::HTTP::VERSION) ? ::Net::HTTP::VERSION : 'loaded'}" do
    origin = ConnectLab::HttpsOrigin.new
    proxy = ConnectLab::MockProxy.start
    response = RubyProxyHeaders::NetHTTP.get(
      "https://127.0.0.1:#{origin.port}/",
      proxy: "http://127.0.0.1:#{proxy.port}",
      proxy_headers: { 'X-ProxyMesh-Country' => 'US' },
      verify_ssl: false,
      open_timeout: 5,
      read_timeout: 5
    )

    expect(response.code).to eq(200)
    expect(response.body).to include('local-https')
    expect(response.proxy_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.7')
    expect(response.proxy_response_headers['x-proxymesh-country-echo']).to eq('US')
  ensure
    proxy&.stop
    origin&.close
  end

  it 'does not write CONNECT bytes when the target host contains CR' do
    server = TCPServer.new('127.0.0.1', 0)
    received = Queue.new
    thread = Thread.new do
      sock = Timeout.timeout(0.4) { server.accept }
      received << sock.readpartial(4096)
      sock.close
    rescue Timeout::Error, EOFError, Errno::ECONNRESET
      received << :none
    end

    http = Net::HTTP.new("evil.com\r\nX-Injected: smuggled", 443, '127.0.0.1', server.addr[1])
    http.use_ssl = true
    http.open_timeout = 1
    http.read_timeout = 1
    http.proxy_connect_request_headers = { 'X-ProxyMesh-Country' => 'US' }

    expect { http.send(:connect) }.to raise_error(ArgumentError, /target host/i)
    payload = Timeout.timeout(0.5) { received.pop }
    expect(payload).to eq(:none)
  ensure
    thread&.kill
    server&.close
  end

  it 'calls upstream timeouted_connect when that method exists' do
    skip "net-http #{net_http_version} opens the socket inline" unless Net::HTTP.private_instance_methods.include?(:timeouted_connect)

    proxy = ConnectLab::MockProxy.start
    http = Net::HTTP.new('127.0.0.1', 9, '127.0.0.1', proxy.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 2
    http.read_timeout = 2
    called = []
    http.singleton_class.prepend(Module.new do
      define_method(:timeouted_connect) do |*args|
        called << true
        super(*args)
      end
    end)

    begin
      http.send(:connect)
    rescue StandardError
      # Port 9 refuses the tunneled target. The assertion is that upstream ran.
      nil
    end
    expect(called).not_to be_empty
  ensure
    proxy&.stop
  end

  it 'keeps TLS-to-proxy (proxy_use_ssl) instead of writing a cleartext CONNECT' do
    sample = Net::HTTP.new('127.0.0.1', 443, '127.0.0.1', 9)
    skip "net-http #{net_http_version} has no HTTPS proxy support" unless sample.respond_to?(:proxy_use_ssl=)

    origin = ConnectLab::HttpsOrigin.new
    proxy = ConnectLab::TlsProxy.new
    response = RubyProxyHeaders::NetHTTP.get(
      "https://127.0.0.1:#{origin.port}/",
      proxy: "https://127.0.0.1:#{proxy.port}",
      proxy_headers: { 'X-ProxyMesh-Country' => 'US' },
      verify_ssl: false,
      open_timeout: 5,
      read_timeout: 5
    )

    expect(response.code).to eq(200)
    expect(response.body).to include('local-https')
    expect(response.proxy_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.9')
    first = Timeout.timeout(2) { proxy.first_bytes.pop }
    # TLS handshake record, not a cleartext "CONNECT".
    expect(first.bytes.first).to eq(0x16)
    head = Timeout.timeout(2) { proxy.connect_heads.pop }
    expect(head).to start_with('CONNECT ')
    expect(head).to include('X-ProxyMesh-Country: US')
  ensure
    proxy&.close
    origin&.close
  end
end
