---
name: ruby-proxy-headers
description: >-
  Send and receive custom headers during HTTPS CONNECT tunneling in Ruby.
  Use when integrating proxy headers with Net::HTTP, Faraday, HTTParty, or Excon.
---

# ruby-proxy-headers

Send custom headers to proxies and receive proxy response headers during HTTPS CONNECT tunneling.

## Installation

```bash
gem install ruby-proxy-headers
```

Or in Gemfile:

```ruby
gem 'ruby-proxy-headers'
```

Install faraday, httparty, or excon as needed.

## Quick Reference

| Library | Module | Key Methods |
|---------|--------|-------------|
| Net::HTTP | `ruby_proxy_headers/net_http` | `patch!`, `proxy_connect_request_headers=` |
| Faraday | `ruby_proxy_headers/faraday` | `FaradayIntegration.connection` |
| HTTParty | `ruby_proxy_headers/httparty` | `ProxyHeadersConnectionAdapter` |
| Excon | `ruby_proxy_headers/excon` | `ExconIntegration.get` (send-only) |

## Usage Patterns

### Net::HTTP

```ruby
require 'uri'
require 'openssl'
require 'ruby_proxy_headers/net_http'

RubyProxyHeaders::NetHTTP.patch!

uri = URI('https://api.ipify.org?format=json')
proxy = URI(ENV.fetch('PROXY_URL'))

http = Net::HTTP.new(uri.host, uri.port, proxy.host, proxy.port, proxy.user, proxy.password)
http.use_ssl = true

http.proxy_connect_request_headers = { 'X-ProxyMesh-IP' => '203.0.113.1' }

res = http.request(Net::HTTP::Get.new(uri))
puts http.last_proxy_connect_response_headers['X-ProxyMesh-IP']
```

Call `RubyProxyHeaders::NetHTTP.patch!` once before creating connections.

### Faraday

```ruby
require 'ruby_proxy_headers/faraday'

conn = RubyProxyHeaders::FaradayIntegration.connection(
  proxy: ENV.fetch('PROXY_URL'),
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' }
)

res = conn.get('https://api.ipify.org?format=json')
puts res.headers['X-ProxyMesh-IP']
```

### HTTParty

```ruby
require 'httparty'
require 'ruby_proxy_headers/httparty'

RubyProxyHeaders::NetHTTP.patch!

proxy = URI(ENV.fetch('PROXY_URL'))
HTTParty.get(
  'https://api.ipify.org?format=json',
  http_proxyaddr: proxy.host,
  http_proxyport: proxy.port,
  http_proxyuser: proxy.user,
  http_proxypass: proxy.password,
  proxy_connect_request_headers: { 'X-ProxyMesh-IP' => '203.0.113.1' },
  connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter
)

puts RubyProxyHeaders.proxy_connect_response_headers['X-ProxyMesh-IP']
```

### Excon (send-only)

Excon supports sending headers on CONNECT but does not expose CONNECT response headers.

```ruby
require 'ruby_proxy_headers/excon'

RubyProxyHeaders::ExconIntegration.get(
  'https://api.ipify.org?format=json',
  proxy_url: ENV.fetch('PROXY_URL'),
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' }
)
```

## Reading Response Headers

- **Net::HTTP**: `http.last_proxy_connect_response_headers`
- **Faraday**: Merged into `response.headers`
- **HTTParty**: `RubyProxyHeaders.proxy_connect_response_headers` (thread-local)

## Proxy Headers

Custom headers sent during CONNECT are proxy-specific. Check your proxy provider's docs.

Example with [ProxyMesh](https://proxymesh.com):

| Header | Direction | Purpose |
|--------|-----------|---------|
| `X-ProxyMesh-Country` | Send | Route through specific country |
| `X-ProxyMesh-IP` | Send/Receive | Request or receive sticky IP |

## Testing

```bash
export PROXY_URL='http://user:pass@proxy.example.com:8080'
bundle exec ruby test/test_proxy_headers.rb -v
```
