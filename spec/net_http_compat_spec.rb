# frozen_string_literal: true

require 'spec_helper'
require 'socket'
require 'timeout'
require_relative 'support/mock_connect_proxy'

RSpec.describe 'net-http CONNECT compatibility' do
  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  before do
    RubyProxyHeaders::NetHTTP.patch!
  end

  it 'round-trips a custom CONNECT header on the installed net-http' do
    origin = MockConnect::Origin.new
    proxy = MockConnect::Proxy.new
    uri = URI("https://127.0.0.1:#{origin.port}/resource")
    http = Net::HTTP.new(uri.host, uri.port, '127.0.0.1', proxy.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 5
    http.read_timeout = 5
    http.proxy_connect_request_headers = { 'X-ProxyMesh-Country' => 'US' }
    request = Net::HTTP::Get.new(uri)
    request['X-App-Secret'] = 'should-not-leak'

    response = http.request(request)

    expect(response.code).to eq('200')
    expect(response.body).to eq('origin-ok')
    expect(http.last_proxy_connect_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.10')
    expect(http.last_proxy_connect_response_headers['x-proxymesh-country-echo']).to eq('US')
    expect(RubyProxyHeaders.proxy_connect_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.10')
    expect(proxy.connect_request).to include('X-ProxyMesh-Country: US')
    expect(proxy.connect_request).not_to include('X-App-Secret')
    expect(origin.request).to include('X-App-Secret: should-not-leak')
    expect(origin.request).not_to include('X-ProxyMesh-Country')
  ensure
    proxy&.stop
    origin&.stop
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
    expect(Timeout.timeout(0.5) { received.pop }).to eq(:none)
  ensure
    thread&.kill
    server&.close
  end

  it 'keeps the patch after WebMock restores the original Net::HTTP' do
    WebMock.enable!
    RubyProxyHeaders::NetHTTP.patch!
    WebMock.disable!

    origin = MockConnect::Origin.new
    proxy = MockConnect::Proxy.new
    uri = URI("https://127.0.0.1:#{origin.port}/")
    http = Net::HTTP.new(uri.host, uri.port, '127.0.0.1', proxy.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 5
    http.read_timeout = 5
    http.proxy_connect_request_headers = { 'X-ProxyMesh-Country' => 'US' }

    response = http.request(Net::HTTP::Get.new(uri))

    expect(response.code).to eq('200')
    expect(http.last_proxy_connect_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.10')
    expect(proxy.connect_request).to include('X-ProxyMesh-Country: US')
  ensure
    proxy&.stop
    origin&.stop
  end

  it 'sends the custom header inside TLS when the proxy uses HTTPS' do
    origin = MockConnect::Origin.new
    proxy = MockConnect::TlsProxy.new
    uri = URI("https://127.0.0.1:#{origin.port}/")
    http = Net::HTTP.new(uri.host, uri.port, '127.0.0.1', proxy.port)
    http.use_ssl = true
    http.proxy_use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.open_timeout = 5
    http.read_timeout = 5
    http.proxy_connect_request_headers = { 'X-ProxyMesh-Country' => 'US' }

    response = http.request(Net::HTTP::Get.new(uri))

    expect(response.code).to eq('200')
    expect(response.body).to eq('origin-ok')
    expect(http.last_proxy_connect_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.9')
    expect(proxy.first_byte).to eq(0x16)
    expect(proxy.connect_request).to start_with('CONNECT ')
    expect(proxy.connect_request).to include('X-ProxyMesh-Country: US')
  ensure
    proxy&.stop
    origin&.stop
  end
end
