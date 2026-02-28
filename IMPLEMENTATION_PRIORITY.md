# Implementation Priority for ruby-proxy-headers

This document outlines the implementation plan for the ruby-proxy-headers gem.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     ruby-proxy-headers gem                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              Core: ProxyHeadersConnection                │    │
│  │  - Direct socket handling for CONNECT with headers      │    │
│  │  - TLS upgrade after CONNECT                            │    │
│  │  - Response header capture                              │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              ▲                                   │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                   Net::HTTP Extension                    │    │
│  │  - Prepend module to override #connect                  │    │
│  │  - Store proxy headers on Net::HTTPResponse             │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              ▲                                   │
│              ┌───────────────┼───────────────┐                   │
│              │               │               │                   │
│  ┌───────────┴───┐  ┌───────┴───────┐  ┌───┴───────────┐       │
│  │    Faraday    │  │   HTTParty    │  │   RestClient  │       │
│  │   Middleware  │  │   Extension   │  │   Extension   │       │
│  └───────────────┘  └───────────────┘  └───────────────┘       │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │           Typhoeus Extension (via Ethon FFI)            │    │
│  │  - Direct libcurl CURLOPT_PROXYHEADER support           │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Phase 1: Core Implementation

### 1.1 ProxyHeadersConnection (lib/ruby_proxy_headers/connection.rb)
- Pure Ruby socket handling
- Build CONNECT request with custom headers
- Parse CONNECT response and capture headers
- TLS upgrade handling
- Thread-safe header storage

### 1.2 Net::HTTP Extension (lib/ruby_proxy_headers/net_http.rb)
- Prepend module to `Net::HTTP`
- Override `connect` method to use ProxyHeadersConnection
- Add `proxy_response_headers` accessor to responses
- Configuration via class-level or instance-level options

## Phase 2: Popular Library Integration

### 2.1 Faraday Middleware (lib/ruby_proxy_headers/faraday.rb)
- Register as Faraday middleware
- Wrap connection with proxy header support
- Store proxy headers in `env[:proxy_response_headers]`
- Access via `response.env[:proxy_response_headers]`

### 2.2 HTTParty Extension (lib/ruby_proxy_headers/httparty.rb)
- Module that can be included in HTTParty classes
- Add `proxy_headers` option to requests
- Store proxy response headers on response object
- Works with existing HTTParty patterns

### 2.3 HTTP.rb Extension (lib/ruby_proxy_headers/http_gem.rb)
- Extend HTTP::Client or use feature injection
- Add `.with_proxy_headers(headers)` chainable method
- Access via `response.proxy_headers`

## Phase 3: Additional Libraries

### 3.1 Typhoeus/Ethon Extension (lib/ruby_proxy_headers/typhoeus.rb)
- Extend Ethon::Easy to expose `CURLOPT_PROXYHEADER`
- Use `CURLOPT_HEADERFUNCTION` for response capture
- Leverage native libcurl support for best performance

### 3.2 Excon Extension (lib/ruby_proxy_headers/excon.rb)
- Middleware/interceptor for Excon
- Wrap connection handling
- Store headers in connection data

### 3.3 RestClient Extension (lib/ruby_proxy_headers/rest_client.rb)
- Leverages Net::HTTP extension
- Add accessor for proxy headers on response

## File Structure

```
ruby-proxy-headers/
├── lib/
│   ├── ruby_proxy_headers.rb          # Main entry point
│   ├── ruby_proxy_headers/
│   │   ├── version.rb                 # Gem version
│   │   ├── connection.rb              # Core proxy connection handler
│   │   ├── net_http.rb                # Net::HTTP extension
│   │   ├── faraday.rb                 # Faraday middleware
│   │   ├── httparty.rb                # HTTParty extension
│   │   ├── http_gem.rb                # HTTP.rb extension
│   │   ├── typhoeus.rb                # Typhoeus/Ethon extension
│   │   ├── excon.rb                   # Excon extension
│   │   └── rest_client.rb             # RestClient extension
├── spec/
│   ├── spec_helper.rb
│   ├── connection_spec.rb
│   ├── net_http_spec.rb
│   ├── faraday_spec.rb
│   ├── httparty_spec.rb
│   └── ...
├── examples/
│   ├── net_http_example.rb
│   ├── faraday_example.rb
│   └── ...
├── ruby_proxy_headers.gemspec
├── Gemfile
├── Rakefile
├── README.md
├── LICENSE
├── CHANGELOG.md
└── docs/                              # ReadTheDocs documentation
    ├── index.md
    ├── getting-started.md
    ├── faraday.md
    └── ...
```

## Technical Challenges

### 1. Socket Interception
Ruby's Net::HTTP creates sockets internally. We need to:
- Intercept before TLS upgrade
- Inject CONNECT request with custom headers
- Parse CONNECT response
- Continue with normal TLS handshake

### 2. Thread Safety
Multiple concurrent requests may share connection pools:
- Use thread-local storage for proxy response headers
- Or attach headers to response object directly

### 3. Connection Pooling
Libraries like Faraday may reuse connections:
- Ensure headers are reset per-request
- Don't interfere with keep-alive

### 4. libcurl Integration (Typhoeus)
- Ethon uses FFI, may need to define additional functions
- `CURLOPT_PROXYHEADER` requires curl >= 7.37.0
- Need to handle version detection

## API Design

### Basic Usage

```ruby
require 'ruby_proxy_headers'

# Net::HTTP
response = RubyProxyHeaders::NetHTTP.get(
  'https://example.com',
  proxy: 'http://user:pass@proxy:8080',
  proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
)
puts response.proxy_response_headers['X-ProxyMesh-IP']

# Faraday
conn = Faraday.new(url: 'https://example.com') do |f|
  f.use RubyProxyHeaders::Faraday::Middleware,
        proxy_headers: { 'X-ProxyMesh-Country' => 'US' }
  f.proxy = 'http://user:pass@proxy:8080'
end
response = conn.get('/')
puts response.env[:proxy_response_headers]['X-ProxyMesh-IP']

# HTTParty
class ProxyClient
  include HTTParty
  include RubyProxyHeaders::HTTParty
  
  http_proxy 'proxy', 8080, 'user', 'pass'
  proxy_headers 'X-ProxyMesh-Country' => 'US'
end
response = ProxyClient.get('https://example.com')
puts response.proxy_response_headers['X-ProxyMesh-IP']
```

## Dependencies

### Required
- Ruby >= 2.7 (for pattern matching, numbered block params)
- No external gems for core functionality

### Optional (for specific integrations)
- faraday (>= 1.0) for Faraday middleware
- httparty (>= 0.18) for HTTParty extension
- http (>= 5.0) for HTTP.rb extension
- typhoeus (>= 1.4) for Typhoeus extension
- excon (>= 0.80) for Excon extension

## Testing Strategy

### Unit Tests
- Mock socket connections
- Test CONNECT request building
- Test response parsing

### Integration Tests
- Use actual proxy (local or test service)
- Verify headers sent and received
- Test with each supported library

### Compatibility Tests
- Test with multiple Ruby versions (2.7, 3.0, 3.1, 3.2, 3.3)
- Test with multiple versions of each library
