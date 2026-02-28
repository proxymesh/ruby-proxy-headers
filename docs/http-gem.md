# HTTP.rb

[HTTP.rb](https://github.com/httprb/http) (the `http` gem) provides a simple Ruby DSL for making HTTP requests. The `RubyProxyHeaders::HTTPGem` module adds proxy header support.

## Installation

```ruby
gem 'http'
gem 'ruby_proxy_headers'
```

## Basic Usage

### Using Client

```ruby
require 'ruby_proxy_headers'

client = RubyProxyHeaders::HTTPGem.create_client(
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

response = client.get('https://api.ipify.org?format=json')

puts "Status: #{response.code}"
puts "Body: #{response.body}"
puts "Proxy IP: #{client.last_proxy_response_headers['x-proxymesh-ip']}"
```

### Standalone Methods

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::HTTPGem.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://proxy:8080',
  proxy_headers: { 'X-Country' => 'US' }
)

puts response.body
```

## API Reference

### `RubyProxyHeaders::HTTPGem.create_client(options)`

Create a client with proxy header support.

**Parameters:**

- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to proxy

**Returns:** `ProxyClient`

### `RubyProxyHeaders::HTTPGem.get(url, options)`

Make a GET request.

**Parameters:**

- `url` (String) - Target URL
- `options` (Hash) - Same as `create_client`

**Returns:** Response object

### `RubyProxyHeaders::HTTPGem.post(url, options)`

Make a POST request.

**Parameters:**

- Same as `get`, plus:
  - `:body` (String) - Request body

## Client Methods

The client supports standard HTTP methods:

```ruby
client = RubyProxyHeaders::HTTPGem.create_client(proxy: '...')

client.get(url)
client.post(url, body: data)
client.put(url, body: data)
client.delete(url)
```

## Accessing Proxy Headers

```ruby
client = RubyProxyHeaders::HTTPGem.create_client(
  proxy: 'http://proxy:8080',
  proxy_headers: { 'X-Country' => 'US' }
)

response = client.get('https://example.com')

# Access via client
puts client.last_proxy_response_headers['x-proxymesh-ip']
```

## Example: Chained Requests

```ruby
require 'ruby_proxy_headers'

client = RubyProxyHeaders::HTTPGem.create_client(
  proxy: ENV['PROXY_URL'],
  proxy_headers: { 'X-ProxyMesh-Session' => 'chain-test' }
)

urls = [
  'https://api.ipify.org?format=json',
  'https://httpbin.org/ip',
  'https://ifconfig.me/ip'
]

urls.each do |url|
  response = client.get(url)
  puts "#{url}: #{response.body.to_s.strip}"
end
```
