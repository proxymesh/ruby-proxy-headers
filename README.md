# ruby-proxy-headers

[![Gem Version](https://badge.fury.io/rb/ruby_proxy_headers.svg)](https://badge.fury.io/rb/ruby_proxy_headers)
[![Documentation](https://img.shields.io/badge/docs-readthedocs-blue)](https://ruby-proxy-headers.readthedocs.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Extensions for Ruby HTTP libraries to support sending custom headers to proxy servers during HTTPS CONNECT tunneling and receiving proxy response headers.

## The Problem

When making HTTPS requests through a proxy server, the client first establishes a tunnel using the HTTP CONNECT method. During this handshake:

1. The client sends `CONNECT target:443 HTTP/1.1` to the proxy
2. The proxy connects to the target and returns `200 Connection established`
3. The client then speaks TLS directly to the target through the tunnel

Standard Ruby HTTP libraries support basic proxy authentication but **do not** allow:
- Sending additional custom headers during CONNECT (e.g., `X-ProxyMesh-Country`)
- Accessing headers returned by the proxy in the CONNECT response (e.g., `X-ProxyMesh-IP`)

This gem solves both problems for popular Ruby HTTP libraries.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ruby_proxy_headers'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install ruby_proxy_headers
```

## Supported Libraries

| Library | Module | Status |
|---------|--------|--------|
| [Net::HTTP](https://ruby-doc.org/stdlib/libdoc/net/http/rdoc/Net/HTTP.html) | `RubyProxyHeaders::NetHTTP` | ✅ |
| [Faraday](https://lostisland.github.io/faraday/) | `RubyProxyHeaders::Faraday` | ✅ |
| [HTTParty](https://github.com/jnunemaker/httparty) | `RubyProxyHeaders::HTTParty` | ✅ |
| [HTTP.rb](https://github.com/httprb/http) | `RubyProxyHeaders::HTTPGem` | ✅ |
| [Typhoeus](https://typhoeus.github.io/) | `RubyProxyHeaders::Typhoeus` | ✅ |
| [Excon](https://github.com/excon/excon) | `RubyProxyHeaders::Excon` | ✅ |
| [RestClient](https://github.com/rest-client/rest-client) | `RubyProxyHeaders::RestClient` | ✅ |

## Quick Start

### Net::HTTP

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::NetHTTP.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Status: #{response.code}"
puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

### Faraday

```ruby
require 'ruby_proxy_headers'
require 'faraday'

conn = Faraday.new(url: 'https://api.ipify.org') do |f|
  f.use RubyProxyHeaders::Faraday::Middleware,
        proxy: 'http://user:pass@proxy.example.com:8080',
        proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  f.adapter Faraday.default_adapter
end

response = conn.get('/?format=json')
puts "Body: #{response.body}"
puts "Proxy IP: #{response.env[:proxy_response_headers]['x-proxymesh-ip']}"
```

### HTTParty

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::HTTParty.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

Or include in a class:

```ruby
require 'httparty'
require 'ruby_proxy_headers'

class ProxyClient
  include HTTParty
  include RubyProxyHeaders::HTTParty
  
  base_uri 'https://api.ipify.org'
  http_proxy 'proxy.example.com', 8080, 'user', 'pass'
  proxy_headers 'X-ProxyMesh-Country' => 'US'
end

response = ProxyClient.get('/?format=json')
puts response.body
```

### HTTP.rb

```ruby
require 'ruby_proxy_headers'

client = RubyProxyHeaders::HTTPGem.create_client(
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

response = client.get('https://api.ipify.org?format=json')
puts "Body: #{response.body}"
puts "Proxy IP: #{client.last_proxy_response_headers['x-proxymesh-ip']}"
```

### Typhoeus

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::Typhoeus.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

### Excon

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::Excon.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

### RestClient

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::RestClient.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

## Core Connection API

For advanced use cases, you can use the core `Connection` class directly:

```ruby
require 'ruby_proxy_headers'

connection = RubyProxyHeaders::Connection.new(
  'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

# Establish tunnel to target
ssl_socket = connection.connect('api.ipify.org', 443)

# Access proxy response headers
puts connection.proxy_response_headers

# Use ssl_socket for your own HTTP implementation
# ...

connection.close
```

## Use Cases

### ProxyMesh Integration

[ProxyMesh](https://proxymesh.com) uses custom headers to control proxy behavior:

```ruby
response = RubyProxyHeaders::NetHTTP.get(
  'https://example.com',
  proxy: 'http://user:pass@us.proxymesh.com:31280',
  proxy_headers: {
    'X-ProxyMesh-Country' => 'US',
    'X-ProxyMesh-Session' => 'session123'
  }
)

# Get the actual IP used
puts "Request made from: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

### Rotating Proxies

```ruby
COUNTRIES = %w[US UK DE FR JP]

COUNTRIES.each do |country|
  response = RubyProxyHeaders::NetHTTP.get(
    'https://api.ipify.org?format=json',
    proxy: ENV['PROXY_URL'],
    proxy_headers: { 'X-ProxyMesh-Country' => country }
  )
  
  puts "#{country}: #{response.body}"
end
```

## Requirements

- Ruby >= 2.7
- OpenSSL

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rake spec` to run the tests.

```bash
git clone https://github.com/proxymeshai/ruby-proxy-headers.git
cd ruby-proxy-headers
bundle install
rake spec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/proxymeshai/ruby-proxy-headers.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Related Projects

- [python-proxy-headers](https://github.com/proxymesh/python-proxy-headers) - Python version
- [javascript-proxy-headers](https://github.com/proxymeshai/javascript-proxy-headers) - JavaScript/Node.js version
