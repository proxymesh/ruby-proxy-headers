# Core API

The core API provides low-level access to proxy connection handling. Use this for advanced use cases or when integrating with libraries not directly supported.

## Connection Class

The `RubyProxyHeaders::Connection` class handles the HTTPS CONNECT tunnel with custom headers.

### Basic Usage

```ruby
require 'ruby_proxy_headers'

connection = RubyProxyHeaders::Connection.new(
  'http://user:pass@proxy.example.com:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

# Establish tunnel
ssl_socket = connection.connect('api.ipify.org', 443)

# Access proxy response headers
puts connection.proxy_response_headers
puts connection.proxy_response_status

# Use the socket for your own HTTP implementation
# ...

connection.close
```

### Constructor

```ruby
RubyProxyHeaders::Connection.new(proxy, options = {})
```

**Parameters:**

- `proxy` (String or Hash) - Proxy configuration
  - String: `'http://user:pass@proxy:8080'`
  - Hash: `{ host: 'proxy', port: 8080, user: 'user', password: 'pass' }`
- `options` (Hash):
  - `:proxy_headers` (Hash) - Headers to send during CONNECT
  - `:connect_timeout` (Integer) - Timeout in seconds (default: 30)
  - `:verify_ssl` (Boolean) - Verify SSL certificates (default: true)

### Instance Methods

#### `connect(target_host, target_port = 443)`

Establish a tunnel through the proxy to the target.

**Returns:** `OpenSSL::SSL::SSLSocket` - TLS-wrapped socket

#### `close`

Close the connection.

### Instance Attributes

- `proxy_response_headers` (Hash) - Headers from proxy CONNECT response
- `proxy_response_status` (Integer) - HTTP status from CONNECT response
- `socket` - The underlying socket

## Utility Methods

### `RubyProxyHeaders.parse_proxy_url(url)`

Parse a proxy URL into components.

```ruby
result = RubyProxyHeaders.parse_proxy_url('http://user:pass@proxy:8080')
# => { host: 'proxy', port: 8080, user: 'user', password: 'pass', scheme: 'http' }
```

### `RubyProxyHeaders.build_auth_header(user, password)`

Build a Basic authentication header.

```ruby
auth = RubyProxyHeaders.build_auth_header('user', 'pass')
# => "Basic dXNlcjpwYXNz"
```

## Error Classes

### `RubyProxyHeaders::Error`

Base error class.

### `RubyProxyHeaders::ConnectError`

Raised when proxy CONNECT fails.

### `RubyProxyHeaders::ProxyAuthenticationError`

Raised when proxy returns 407 (authentication required).

## Example: Custom HTTP Implementation

```ruby
require 'ruby_proxy_headers'

connection = RubyProxyHeaders::Connection.new(
  ENV['PROXY_URL'],
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)

begin
  socket = connection.connect('example.com', 443)
  
  # Send HTTP request
  socket.write("GET / HTTP/1.1\r\n")
  socket.write("Host: example.com\r\n")
  socket.write("Connection: close\r\n")
  socket.write("\r\n")
  
  # Read response
  response = socket.read
  puts response
  
  # Access proxy headers
  puts "Proxy IP: #{connection.proxy_response_headers['x-proxymesh-ip']}"
ensure
  connection.close
end
```

## Example: Integration with Custom Client

```ruby
require 'ruby_proxy_headers'

class CustomHttpClient
  def initialize(proxy_url, proxy_headers = {})
    @proxy_url = proxy_url
    @proxy_headers = proxy_headers
  end
  
  def get(url)
    uri = URI.parse(url)
    connection = RubyProxyHeaders::Connection.new(
      @proxy_url,
      proxy_headers: @proxy_headers
    )
    
    begin
      socket = connection.connect(uri.host, uri.port || 443)
      
      # Build request
      request = "GET #{uri.request_uri} HTTP/1.1\r\n"
      request += "Host: #{uri.host}\r\n"
      request += "Connection: close\r\n"
      request += "\r\n"
      
      socket.write(request)
      response = socket.read
      
      {
        body: parse_body(response),
        proxy_headers: connection.proxy_response_headers
      }
    ensure
      connection.close
    end
  end
  
  private
  
  def parse_body(response)
    # Simple body extraction
    response.split("\r\n\r\n", 2).last
  end
end

client = CustomHttpClient.new(
  ENV['PROXY_URL'],
  'X-ProxyMesh-Country' => 'US'
)

result = client.get('https://api.ipify.org?format=json')
puts result[:body]
```
