# Faraday

[Faraday](https://lostisland.github.io/faraday/) 2.x talks to `Net::HTTP` through `faraday-net_http`. This gem registers the adapter `:ruby_proxy_headers_net_http`, which uses Faraday's public `net_http_connection` and `call` hooks. It does not override the private `request_with_wrapped_block` method.

## Installation

```ruby
gem 'faraday'
gem 'faraday-net_http'
gem 'ruby-proxy-headers'
```

## Basic usage

```ruby
require 'ruby_proxy_headers/faraday'

conn = RubyProxyHeaders::FaradayIntegration.connection(
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' } # optional
)
response = conn.get('https://api.ipify.org?format=json')

puts response.status
puts response.body
puts response.headers['X-ProxyMesh-IP']
```

`FaradayIntegration.connection` calls `RubyProxyHeaders::NetHTTP.patch!`, builds a Faraday connection with the registered adapter, and sets `proxy_connect_request_headers` on the `Net::HTTP` object. CONNECT response headers are merged into `response.headers` (existing response headers are left in place).

Pass a block to configure the builder, including TLS verification for a lab proxy:

```ruby
conn = RubyProxyHeaders::FaradayIntegration.connection(
  proxy: ENV.fetch('PROXY_URL'),
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' }
) do |f|
  f.ssl.verify = false
end
```

## HTTPS proxies

An `https://` proxy URL is passed through to Faraday. `faraday-net_http` sets `proxy_use_ssl` on `Net::HTTP` itself, and the patch leaves that path on the installed net-http.
