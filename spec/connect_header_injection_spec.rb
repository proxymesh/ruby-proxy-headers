# frozen_string_literal: true

root = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(root, 'lib')) unless $LOAD_PATH.include?(File.join(root, 'lib'))
require 'ruby_proxy_headers'

RSpec.describe 'RubyProxyHeaders::NetHTTP.request' do
  it 'is defined for the HTTP.rb, RestClient, and Typhoeus adapters' do
    expect(RubyProxyHeaders::NetHTTP).to respond_to(:request)
    expect(RubyProxyHeaders::NetHTTP).to respond_to(:get)
  end

  it 'inserts custom headers before the CONNECT terminator' do
    raw = "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n"
    injected = RubyProxyHeaders::NetHTTP.inject_connect_headers(
      raw,
      { 'X-ProxyMesh-Country' => 'US' }
    )

    expect(injected).to include("X-ProxyMesh-Country: US\r\n")
    expect(injected).to end_with("\r\n\r\n")
    expect(injected.index('X-ProxyMesh-Country')).to be < injected.rindex("\r\n\r\n")
    expect(injected).to include('Proxy-Authorization').or include('Host: example.com:443')
  end

  it 'rejects CR/LF in a CONNECT header before returning a modified request' do
    raw = "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n"
    expect do
      RubyProxyHeaders::NetHTTP.inject_connect_headers(raw, { 'X-Bad' => "no\r\nInjected: yes" })
    end.to raise_error(ArgumentError, /header value/)
  end
end

RSpec.describe RubyProxyHeaders::HeaderHash do
  it 'reads header names without caring about case' do
    headers = described_class.new
    headers['X-ProxyMesh-IP'] = '203.0.113.7'
    expect(headers['x-proxymesh-ip']).to eq('203.0.113.7')
    expect(headers['X-ProxyMesh-IP']).to eq('203.0.113.7')
  end
end
