# Faraday

[Faraday](https://lostisland.github.io/faraday/) is a popular HTTP client library with a middleware architecture. The `RubyProxyHeaders::Faraday` module provides middleware for proxy header support.

## Installation

Add Faraday to your Gemfile:

```ruby
gem 'faraday'
gem 'ruby_proxy_headers'
```

## Basic Usage

### Using Middleware

```ruby
require 'faraday'
require 'ruby_proxy_headers'

conn = Faraday.new(url: 'https://api.ipify.org') do |f|
  f.use RubyProxyHeaders::Faraday::Middleware,
        proxy: 'http://user:pass@proxy.example.com:8080',
        proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  f.adapter Faraday.default_adapter
end

response = conn.get('/?format=json')

puts "Status: #{response.status}"
puts "Body: #{response.body}"
puts "Proxy IP: #{response.env[:proxy_response_headers]['x-proxymesh-ip']}"
```

### Using Helper Method

```ruby
require 'ruby_proxy_headers'

conn = RubyProxyHeaders::Faraday.create_connection(
  'https://api.ipify.org',
  proxy: 'http://user:pass@proxy:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

response = conn.get('/?format=json')
puts response.body
```

## Middleware Options

### `RubyProxyHeaders::Faraday::Middleware`

**Options:**

- `:proxy` (String) - Proxy URL (required)
- `:proxy_headers` (Hash) - Headers to send to proxy during CONNECT
- `:on_proxy_connect` (Proc) - Callback when proxy connection is established

### Callback Example

```ruby
conn = Faraday.new do |f|
  f.use RubyProxyHeaders::Faraday::Middleware,
        proxy: 'http://proxy:8080',
        proxy_headers: { 'X-Country' => 'US' },
        on_proxy_connect: ->(headers) {
          puts "Connected via: #{headers['x-proxymesh-ip']}"
        }
  f.adapter Faraday.default_adapter
end
```

## Accessing Proxy Headers

Proxy response headers are stored in the Faraday environment:

```ruby
response = conn.get('/')
proxy_headers = response.env[:proxy_response_headers]

puts proxy_headers['x-proxymesh-ip']
puts proxy_headers['x-proxymesh-country']
```

## API Reference

### `RubyProxyHeaders::Faraday.create_connection(url, options)`

Create a Faraday connection with proxy header support.

**Parameters:**

- `url` (String) - Base URL
- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to proxy
  - Additional Faraday options

**Returns:** `Faraday::Connection`

## Example: Session Persistence

```ruby
require 'faraday'
require 'ruby_proxy_headers'

session_id = "session-#{SecureRandom.hex(8)}"

conn = Faraday.new do |f|
  f.use RubyProxyHeaders::Faraday::Middleware,
        proxy: 'http://user:pass@us.proxymesh.com:31280',
        proxy_headers: { 'X-ProxyMesh-Session' => session_id }
  f.adapter Faraday.default_adapter
end

5.times do |i|
  response = conn.get('https://api.ipify.org?format=json')
  puts "Request #{i + 1}: #{response.body}"
end
```
