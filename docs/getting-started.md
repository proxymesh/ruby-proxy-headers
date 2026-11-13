# Getting Started

## Installation

```ruby
gem 'ruby-proxy-headers'
```

```bash
gem install ruby-proxy-headers
```

Install `faraday` and `faraday-net_http`, `httparty`, `http` (>= 6), `rest-client`, `typhoeus` (~> 1.7), or `excon` only for the client you use.

Proxy header names are documented at <https://docs.proxymesh.com/>. Examples below use `http://user:pass@proxy.example.com:31280`.

## Net::HTTP

```ruby
require 'uri'
require 'ruby_proxy_headers/net_http'

RubyProxyHeaders::NetHTTP.patch!

uri = URI('https://api.ipify.org?format=json')
proxy = URI('http://user:pass@proxy.example.com:31280')
http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
http.use_ssl = true
http.proxy_connect_request_headers = { 'X-ProxyMesh-Country' => 'US' }
response = http.request(Net::HTTP::Get.new(uri))
puts http.last_proxy_connect_response_headers['X-ProxyMesh-IP']
```

## Faraday

```ruby
require 'ruby_proxy_headers/faraday'

conn = RubyProxyHeaders::FaradayIntegration.connection(
  proxy: 'http://user:pass@proxy.example.com:31280',
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' }
)
puts conn.get('https://api.ipify.org?format=json').headers['X-ProxyMesh-IP']
```

## HTTParty

```ruby
require 'httparty'
require 'ruby_proxy_headers/httparty'

RubyProxyHeaders::NetHTTP.patch!
proxy = URI('http://user:pass@proxy.example.com:31280')
HTTParty.get(
  'https://api.ipify.org?format=json',
  http_proxyaddr: proxy.host,
  http_proxyport: proxy.port,
  http_proxyuser: proxy.user,
  http_proxypass: proxy.password,
  proxy_connect_request_headers: { 'X-ProxyMesh-Country' => 'US' },
  connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter
)
puts RubyProxyHeaders.proxy_connect_response_headers['X-ProxyMesh-IP']
```

Per-library pages: [Net::HTTP](net-http.md), [Faraday](faraday.md), [HTTParty](httparty.md), [HTTP.rb](http-gem.md), [Typhoeus](typhoeus.md), [RestClient](rest-client.md), [Excon](excon.md).
