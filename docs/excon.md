# Excon

[Excon](https://github.com/excon/excon) already sends extra CONNECT headers through `:ssl_proxy_headers`. `RubyProxyHeaders::ExconIntegration.get` maps a proxy URL and header hash onto that option.

Excon does not expose the CONNECT response on the origin response, so `X-ProxyMesh-IP` is not readable from this helper.

## Installation

```ruby
gem 'excon'
gem 'ruby-proxy-headers'
```

## Basic usage

```ruby
require 'ruby_proxy_headers/excon'

response = RubyProxyHeaders::ExconIntegration.get(
  'https://api.ipify.org?format=json',
  proxy_url: 'http://user:pass@proxy.example.com:8080',
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts response.status
puts response.body
```

`proxy_connect_headers` is sent as Excon's `:ssl_proxy_headers`. Extra keyword arguments are merged into the `Excon.get` options. A proxy URL without a scheme is treated as `http://`.
