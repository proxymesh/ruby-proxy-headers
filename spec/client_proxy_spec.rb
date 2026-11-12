# frozen_string_literal: true

require 'spec_helper'
require 'ruby_proxy_headers/faraday'
require 'ruby_proxy_headers/http_gem'
require 'ruby_proxy_headers/httparty'
require 'ruby_proxy_headers/rest_client'
require 'timeout'
require_relative 'support/mock_connect_proxy'

RSpec.describe 'client CONNECT headers' do
  around do |example|
    WebMock.disable!
    example.run
  ensure
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  let(:proxy_headers) { { 'X-ProxyMesh-Country' => 'US' } }

  def open_lab
    origin = MockConnect::Origin.new
    proxy = MockConnect::Proxy.new
    [origin, proxy, "https://127.0.0.1:#{origin.port}/resource", "http://127.0.0.1:#{proxy.port}"]
  end

  def expect_separated(origin, proxy)
    expect(proxy.connect_request).to include('X-ProxyMesh-Country: US')
    expect(proxy.connect_request).not_to include('X-App-Secret')
    expect(origin.request).to include('X-App-Secret: should-not-leak')
    expect(origin.request).not_to include('X-ProxyMesh-Country')
  end

  it 'uses HTTP.rb proxy_headers on CONNECT and reads X-ProxyMesh-IP' do
    origin, proxy, url, proxy_url = open_lab
    client = RubyProxyHeaders::HTTPGem.create_client(proxy: proxy_url, proxy_headers: proxy_headers)
    response = client.get(
      url,
      headers: { 'X-App-Secret' => 'should-not-leak' },
      verify_ssl: false,
      open_timeout: 5,
      read_timeout: 5
    )

    expect(response.code).to eq(200)
    expect(response.body.to_s).to eq('origin-ok')
    expect(response.proxy_response_headers).to be_a(Hash)
    expect(response.proxy_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.10')
    expect(client.last_proxy_response_headers['X-ProxyMesh-Country-Echo']).to eq('US')
    expect_separated(origin, proxy)
  ensure
    proxy&.stop
    origin&.stop
  end

  it 'uses RestClient for HTTPS and reads X-ProxyMesh-IP from CONNECT' do
    origin, proxy, url, proxy_url = open_lab
    response = RubyProxyHeaders::RestClient.get(
      url,
      proxy: proxy_url,
      proxy_headers: proxy_headers,
      headers: { 'X-App-Secret' => 'should-not-leak' },
      verify_ssl: false,
      open_timeout: 5,
      read_timeout: 5
    )

    expect(response.code).to eq(200)
    expect(response.body).to eq('origin-ok')
    expect(response.proxy_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.10')
    expect(response.proxy_response_headers['X-ProxyMesh-Country-Echo']).to eq('US')
    expect_separated(origin, proxy)
  ensure
    proxy&.stop
    origin&.stop
  end

  it 'merges CONNECT response headers through Faraday public adapter methods' do
    owner = RubyProxyHeaders::FaradayAdapter::NetHttp.instance_method(:request_with_wrapped_block).owner
    expect(owner).to eq(Faraday::Adapter::NetHttp)

    origin, proxy, url, proxy_url = open_lab
    connection = RubyProxyHeaders::FaradayIntegration.connection(
      proxy: proxy_url,
      proxy_connect_headers: proxy_headers
    ) do |builder|
      builder.ssl.verify = false
    end
    response = connection.get(url) do |request|
      request.headers['X-App-Secret'] = 'should-not-leak'
    end

    expect(response.status).to eq(200)
    expect(response.body).to eq('origin-ok')
    expect(response.headers['X-ProxyMesh-IP']).to eq('203.0.113.10')
    expect(response.headers['X-ProxyMesh-Country-Echo']).to eq('US')
    expect_separated(origin, proxy)
  ensure
    proxy&.stop
    origin&.stop
  end

  it 'reads X-ProxyMesh-IP for HTTParty' do
    origin, proxy, url, proxy_url = open_lab
    RubyProxyHeaders::NetHTTP.patch!
    parsed = URI(proxy_url)
    response = HTTParty.get(
      url,
      http_proxyaddr: parsed.host,
      http_proxyport: parsed.port,
      verify: false,
      headers: { 'X-App-Secret' => 'should-not-leak' },
      proxy_connect_request_headers: proxy_headers,
      connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter,
      timeout: 5
    )

    expect(response.code).to eq(200)
    headers = RubyProxyHeaders.proxy_connect_response_headers
    expect(headers['X-ProxyMesh-IP']).to eq('203.0.113.10')
    expect(headers['X-ProxyMesh-Country-Echo']).to eq('US')
    expect_separated(origin, proxy)
  ensure
    proxy&.stop
    origin&.stop
  end
end
