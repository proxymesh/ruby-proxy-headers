# Excon

[Excon](https://github.com/excon/excon) already sends extra CONNECT headers as `:ssl_proxy_headers`. `RubyProxyHeaders::ExconIntegration.get` passes them through.

Excon does not expose the CONNECT response on the origin response, so `X-ProxyMesh-IP` is not readable from this client. See [DEFERRED.md](../DEFERRED.md).

## Installation

```ruby
gem 'excon', '~> 1.4'
gem 'ruby-proxy-headers'
```

## Usage

```ruby
require 'ruby_proxy_headers/excon'

response = RubyProxyHeaders::ExconIntegration.get(
  'https://api.ipify.org?format=json',
  proxy_url: 'http://user:pass@proxy.example.com:31280',
  proxy_connect_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts response.status
puts response.body
```

Header names are documented at <https://docs.proxymesh.com/>.
