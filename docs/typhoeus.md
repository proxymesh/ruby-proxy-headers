# Typhoeus

[Typhoeus](https://typhoeus.github.io/) wraps libcurl. `RubyProxyHeaders::Typhoeus` sends custom proxy headers with `CURLOPT_PROXYHEADER` and reads the CONNECT response.

Requires Typhoeus 1.7 (Ethon >= 0.19.1) and libcurl with `CURLOPT_PROXYHEADER`. The gem does not depend on Typhoeus at runtime.

Proxy header names are documented at <https://docs.proxymesh.com/>.

## Installation

```ruby
gem 'typhoeus', '~> 1.7'
gem 'ruby-proxy-headers'
```

## Basic Usage

```ruby
require 'ruby_proxy_headers/typhoeus'

response = RubyProxyHeaders::Typhoeus.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:31280',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts response.code
puts response.body
puts response.proxy_response_headers['X-ProxyMesh-IP']
```

`proxy_headers` are sent only to the proxy (`headeropt: :separate`). On HTTPS that is the CONNECT request. `headers:` is the origin request and is not copied onto CONNECT.

`response.headers` stays the origin response. The CONNECT response, including `X-ProxyMesh-IP`, is `response.proxy_response_headers`. Lookup is case-insensitive.

`post` takes the same proxy arguments plus `body:`.

```ruby
RubyProxyHeaders::Typhoeus.post(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:31280',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' },
  body: '{"q":"example"}'
)
```

Header names and values are rejected when they contain CR, LF, or NUL.
