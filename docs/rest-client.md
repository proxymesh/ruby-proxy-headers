# RestClient

[RestClient](https://github.com/rest-client/rest-client) is a simple REST client. The `RubyProxyHeaders::RestClient` module adds proxy header support.

## Installation

```ruby
gem 'rest-client'
gem 'ruby_proxy_headers'
```

## Basic Usage

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::RestClient.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Status: #{response.code}"
puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

## API Reference

### `RubyProxyHeaders::RestClient.get(url, options)`

Make a GET request.

**Parameters:**

- `url` (String) - Target URL
- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to proxy
  - `:headers` (Hash) - Request headers

**Returns:** `ProxyResponse`

### `RubyProxyHeaders::RestClient.post(url, options)`

Make a POST request.

**Parameters:**

- Same as `get`, plus:
  - `:payload` (String/Hash) - Request body

### `RubyProxyHeaders::RestClient.put(url, options)`

Make a PUT request.

### `RubyProxyHeaders::RestClient.delete(url, options)`

Make a DELETE request.

## Response Object

```ruby
response.code                    # HTTP status code
response.body                    # Response body
response.headers                 # Response headers
response.proxy_response_headers  # Proxy CONNECT response headers
```

## Example: RESTful API

```ruby
require 'ruby_proxy_headers'
require 'json'

proxy_opts = {
  proxy: ENV['PROXY_URL'],
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
}

# Create
response = RubyProxyHeaders::RestClient.post(
  'https://jsonplaceholder.typicode.com/posts',
  payload: { title: 'Test', body: 'Content', userId: 1 }.to_json,
  headers: { 'Content-Type' => 'application/json' },
  **proxy_opts
)
puts "Created: #{JSON.parse(response.body)['id']}"

# Read
response = RubyProxyHeaders::RestClient.get(
  'https://jsonplaceholder.typicode.com/posts/1',
  **proxy_opts
)
puts "Read: #{JSON.parse(response.body)['title']}"
```
