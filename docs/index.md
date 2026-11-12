# ruby-proxy-headers

Send and receive custom proxy headers during HTTPS CONNECT tunneling in Ruby.

## The Problem

When making HTTPS requests through a proxy server, a tunnel is established using the HTTP CONNECT method:

```
Client → CONNECT example.com:443 HTTP/1.1 → Proxy → Target
       ← 200 Connection established ←
       ←→ [TLS encrypted traffic] ←→
```

Standard Ruby HTTP libraries support basic proxy authentication but **do not** allow:

- Sending additional custom headers during CONNECT (e.g., `X-ProxyMesh-Country`)
- Accessing headers returned by the proxy (e.g., `X-ProxyMesh-IP`)

**ruby-proxy-headers** solves both problems.

## Features

- **Send custom headers** to the proxy during HTTPS CONNECT
- **Receive proxy response headers** from the CONNECT response
- **Support for 7 popular Ruby HTTP libraries**
- **Thread-safe** implementation
- **Pure Ruby** core (no native extensions required)

## Supported Libraries

| Library | Module | Status |
|---------|--------|--------|
| Net::HTTP | `RubyProxyHeaders::NetHTTP` | ✅ |
| Faraday | `RubyProxyHeaders::FaradayIntegration` | ✅ |
| HTTParty | `RubyProxyHeaders::ProxyHeadersConnectionAdapter` | ✅ |
| HTTP.rb | `RubyProxyHeaders::HTTPGem` | ✅, http gem >= 6 |
| Typhoeus | `RubyProxyHeaders::Typhoeus` | ✅, Typhoeus ~> 1.7 |
| Excon | `RubyProxyHeaders::ExconIntegration` | Send only |
| RestClient | `RubyProxyHeaders::RestClient` | ✅ |

## Quick Start

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

puts response.code
puts response.body
puts http.last_proxy_connect_response_headers['X-ProxyMesh-IP']
```

## Use Cases

### ProxyMesh Integration

[ProxyMesh](https://docs.proxymesh.com/) uses custom headers for:

- **Country selection**: `X-ProxyMesh-Country: US`
- **Session persistence**: `X-ProxyMesh-Session: abc123`
- **IP assignment feedback**: Returns `X-ProxyMesh-IP` in response

### Proxy Service Headers

Many proxy services use custom headers for:

- Geolocation targeting
- Session management
- Usage tracking
- Load balancing hints

## Installation

Add to your Gemfile:

```ruby
gem 'ruby-proxy-headers'
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install ruby_proxy_headers
```

## Requirements

- Ruby >= 3.2
- OpenSSL (included in standard Ruby)

## Related Projects

- [python-proxy-headers](https://github.com/proxymesh/python-proxy-headers) - Python version
- [javascript-proxy-headers](https://github.com/proxymeshai/javascript-proxy-headers) - JavaScript/Node.js version
