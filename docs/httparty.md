# HTTParty

[HTTParty](https://github.com/jnunemaker/httparty) makes HTTP fun! The `RubyProxyHeaders::HTTParty` module provides both standalone functions and a mixin for class-based usage.

## Installation

```ruby
gem 'httparty'
gem 'ruby_proxy_headers'
```

## Basic Usage

### Standalone Functions

```ruby
require 'ruby_proxy_headers'

response = RubyProxyHeaders::HTTParty.get(
  'https://api.ipify.org?format=json',
  proxy: 'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

puts "Status: #{response.code}"
puts "Body: #{response.body}"
puts "Proxy IP: #{response.proxy_response_headers['x-proxymesh-ip']}"
```

### Class-Based Usage

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
puts response.proxy_response_headers['x-proxymesh-ip']
```

## API Reference

### Standalone Methods

#### `RubyProxyHeaders::HTTParty.get(url, options)`

Make a GET request.

**Parameters:**

- `url` (String) - Target URL
- `options` (Hash):
  - `:proxy` (String) - Proxy URL (required)
  - `:proxy_headers` (Hash) - Headers to send to proxy
  - `:headers` (Hash) - Request headers

**Returns:** Response with `proxy_response_headers` accessor

#### `RubyProxyHeaders::HTTParty.post(url, options)`

Make a POST request.

**Parameters:**

- Same as `get`, plus:
  - `:body` (String/Hash) - Request body

### Class Methods (when including module)

#### `proxy_headers(headers)`

Set default proxy headers for all requests.

```ruby
class MyClient
  include HTTParty
  include RubyProxyHeaders::HTTParty
  
  proxy_headers 'X-Country' => 'US', 'X-Session' => 'abc'
end
```

## Example: Multiple Countries

```ruby
require 'ruby_proxy_headers'

COUNTRIES = %w[US UK DE FR JP]

COUNTRIES.each do |country|
  response = RubyProxyHeaders::HTTParty.get(
    'https://api.ipify.org?format=json',
    proxy: ENV['PROXY_URL'],
    proxy_headers: { 'X-ProxyMesh-Country' => country }
  )
  
  puts "#{country}: #{response.body}"
end
```

## Example: Persistent Client

```ruby
require 'httparty'
require 'ruby_proxy_headers'

class IPChecker
  include HTTParty
  include RubyProxyHeaders::HTTParty
  
  base_uri 'https://api.ipify.org'
  format :json
  
  http_proxy 'us.proxymesh.com', 31280, ENV['PROXY_USER'], ENV['PROXY_PASS']
  proxy_headers 'X-ProxyMesh-Session' => 'persistent'
  
  def self.check_ip
    response = get('/?format=json')
    {
      ip: response['ip'],
      proxy_ip: response.proxy_response_headers['x-proxymesh-ip']
    }
  end
end

puts IPChecker.check_ip
```
