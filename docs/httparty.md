# HTTParty

[HTTParty](https://github.com/jnunemaker/httparty) uses `Net::HTTP`. `RubyProxyHeaders::ProxyHeadersConnectionAdapter` copies CONNECT request headers onto that connection. Read the proxy's CONNECT response from the thread-local `RubyProxyHeaders.proxy_connect_response_headers`.

## Installation

```ruby
gem 'httparty'
gem 'ruby-proxy-headers'
```

## Basic usage

```ruby
require 'httparty'
require 'ruby_proxy_headers/httparty'

RubyProxyHeaders::NetHTTP.patch!

proxy = URI('http://user:pass@proxy.example.com:8080')
response = HTTParty.get(
  'https://api.ipify.org?format=json',
  http_proxyaddr: proxy.host,
  http_proxyport: proxy.port,
  http_proxyuser: proxy.user,
  http_proxypass: proxy.password,
  proxy_connect_request_headers: { 'X-ProxyMesh-Country' => 'US' },
  connection_adapter: RubyProxyHeaders::ProxyHeadersConnectionAdapter
)

puts response.code
puts response.body
puts RubyProxyHeaders.proxy_connect_response_headers['X-ProxyMesh-IP']
```

`proxy_connect_headers` is accepted as an alias of `proxy_connect_request_headers`. Call `NetHTTP.patch!` once before the first request. The thread-local headers are whatever the most recent CONNECT on this thread returned.
