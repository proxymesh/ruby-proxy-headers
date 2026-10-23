# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'http'
require 'rest-client'
require 'typhoeus'
require 'ruby_proxy_headers/faraday'
require 'ruby_proxy_headers/http_gem'
require 'ruby_proxy_headers/httparty'
require 'ruby_proxy_headers/rest_client'
require 'ruby_proxy_headers/typhoeus'
require_relative 'support/connect_lab'

RSpec.describe 'local mock proxy CONNECT headers' do
  before do
    WebMock.disable! if defined?(WebMock)
    @origin = ConnectLab::HttpsOrigin.new
    @proxy = ConnectLab::MockProxy.start
  end

  after do
    @proxy&.stop
    @origin&.close
    if defined?(WebMock)
      WebMock.enable!
      WebMock.disable_net_connect!
    end
  end

  let(:proxy_url) { "http://127.0.0.1:#{@proxy.port}" }
  let(:target_url) { "https://127.0.0.1:#{@origin.port}/resource" }
  let(:proxy_headers) { { 'X-ProxyMesh-Country' => 'US' } }

  def expect_tunnel(proxy_response_headers, body)
    expect(body).to include('local-https')
    expect(ConnectLab.header(proxy_response_headers, 'X-ProxyMesh-IP')).to eq('203.0.113.7')
    expect(ConnectLab.header(proxy_response_headers, 'X-ProxyMesh-Country-Echo')).to eq('US')
    origin_request = Timeout.timeout(2) { @origin.requests.pop }
    expect(origin_request).not_to include('X-ProxyMesh-Country')
  end

  it 'sends the custom header on CONNECT for Net::HTTP and reads the proxy response' do
    response = RubyProxyHeaders::NetHTTP.get(
      target_url,
      proxy: proxy_url,
      proxy_headers: proxy_headers,
      verify_ssl: false,
      open_timeout: 5,
      read_timeout: 5
    )

    expect(response.code).to eq(200)
    expect_tunnel(response.proxy_response_headers, response.body)
  end

  it 'sends the custom header on CONNECT for HTTP.rb and reads the proxy response' do
    client = RubyProxyHeaders::HTTPGem.create_client(
      proxy: proxy_url,
      proxy_headers: proxy_headers
    )
    response = client.get(target_url, verify_ssl: false, open_timeout: 5, read_timeout: 5)

    expect(response.code).to eq(200)
    expect(client.last_proxy_response_headers['X-ProxyMesh-IP']).to eq('203.0.113.7')
    expect_tunnel(response.proxy_response_headers, response.body)
  end

  it 'sends the custom header on CONNECT for RestClient and reads the proxy response' do
    response = RubyProxyHeaders::RestClient.get(
      target_url,
      proxy: proxy_url,
      proxy_headers: proxy_headers,
      verify_ssl: false,
      open_timeout: 5,
      read_timeout: 5
    )

    expect(response.code).to eq(200)
    expect_tunnel(response.proxy_response_headers, response.body)
  end

  it 'sends the custom header on CONNECT for Typhoeus and reads the proxy response' do
    response = RubyProxyHeaders::Typhoeus.get(
      target_url,
      proxy: proxy_url,
      proxy_headers: proxy_headers,
      verify_ssl: false,
      open_timeout: 5,
      read_timeout: 5
    )

    expect(response).to be_success
    expect_tunnel(response.proxy_response_headers, response.body)
  end

  it 'sends the custom header on CONNECT for Faraday and exposes proxy response headers' do
    connection = RubyProxyHeaders::FaradayIntegration.connection(
      proxy: proxy_url,
      proxy_connect_headers: proxy_headers
    ) do |builder|
      builder.ssl.verify = false
    end
    response = connection.get(target_url)

    expect(response.status).to eq(200)
    expect(response.headers['X-ProxyMesh-IP']).to eq('203.0.113.7')
    expect(response.headers['X-ProxyMesh-Country-Echo']).to eq('US')
    origin_request = Timeout.timeout(2) { @origin.requests.pop }
    expect(origin_request).not_to include('X-ProxyMesh-Country')
    expect(response.body).to include('local-https')
  end

  it 'sends the custom header on CONNECT for HTTParty and reads the proxy response' do
    RubyProxyHeaders::NetHTTP.patch!
    proxy = URI(proxy_url)
    response = HTTParty.get(
      target_url,
      http_proxyaddr: proxy.host,
      http_proxyport: proxy.port,
      verify: false,
      proxy_connect_request_headers: proxy_headers,
      connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter,
      timeout: 5
    )

    expect(response.code).to eq(200)
    headers = RubyProxyHeaders.proxy_connect_response_headers
    expect(ConnectLab.header(headers, 'X-ProxyMesh-IP')).to eq('203.0.113.7')
    expect(ConnectLab.header(headers, 'X-ProxyMesh-Country-Echo')).to eq('US')
  end
end
