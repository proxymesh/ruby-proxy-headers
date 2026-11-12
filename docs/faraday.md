# Faraday

[Faraday](https://lostisland.github.io/faraday/) 2.x with `faraday-net_http` 3.4 or 3.5. `RubyProxyHeaders::FaradayIntegration` builds a connection whose adapter merges CONNECT response headers into `response.headers`.

Proxy header names are documented at <https://docs.proxymesh.com/>.

## Installation

```ruby
gem 'faraday', '~> 2.14'
gem 'faraday-net_http', '~> 3.4'
gem 'ruby-proxy-headers'
```

## Usage

```ruby
require 'ruby_proxy_headers/faraday'

conn = RubyProxyHeaders::FaradayIntegration.connection(
  proxy: 'http://user:pass@proxy.example.com:31280',
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' }
)

response = conn.get('https://api.ipify.org?format=json')
puts response.headers['X-ProxyMesh-IP']
```

`proxy_connect_headers` are sent only on the CONNECT request. Origin headers are the normal Faraday request headers. When both sides use the same header name, the origin value is kept.
