# HTTParty

[HTTParty](https://github.com/jnunemaker/httparty) uses Net::HTTP. Pass `RubyProxyHeaders::ProxyHeadersConnectionAdapter` and call `RubyProxyHeaders::NetHTTP.patch!` once. CONNECT response headers are on the thread afterward, not on the HTTParty response.

Proxy header names are documented at <https://docs.proxymesh.com/>.

## Installation

```ruby
gem 'httparty', '~> 0.24'
gem 'ruby-proxy-headers'
```

## Usage

```ruby
require 'httparty'
require 'ruby_proxy_headers/httparty'

RubyProxyHeaders::NetHTTP.patch!

proxy = URI('http://user:pass@proxy.example.com:31280')
response = HTTParty.get(
  'https://api.ipify.org?format=json',
  http_proxyaddr: proxy.host,
  http_proxyport: proxy.port,
  http_proxyuser: proxy.user,
  http_proxypass: proxy.password,
  proxy_connect_request_headers: { 'X-ProxyMesh-Country' => 'US' },
  connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter
)

puts response.body
puts RubyProxyHeaders.proxy_connect_response_headers['X-ProxyMesh-IP']
```
