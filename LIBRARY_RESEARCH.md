# Ruby HTTP Library Research for Proxy Header Support

This document analyzes popular Ruby HTTP and web scraping libraries to determine their proxy support capabilities and the feasibility of extending them to support custom proxy headers during HTTPS CONNECT tunneling.

## The Problem

When making HTTPS requests through a proxy:
1. The client first establishes a tunnel via HTTP CONNECT to the proxy
2. The proxy connects to the target server and returns a `200 Connection established` response
3. The client then speaks TLS directly to the target through the tunnel

Most Ruby HTTP clients support basic proxy authentication (via `Proxy-Authorization` header), but **none** provide APIs to:
- Send additional custom headers during CONNECT (e.g., `X-ProxyMesh-Country`)
- Access headers returned by the proxy in the CONNECT response (e.g., `X-ProxyMesh-IP`)

## Library Analysis

### 1. Net::HTTP (Standard Library)

**GitHub:** Ruby stdlib  
**Downloads:** Built-in (100% of Ruby apps)

**Proxy Support:**
- Basic proxy via `start(host, port, p_addr, p_port, p_user, p_pass)`
- Proxy authentication handled internally

**Custom CONNECT Headers:** ❌ No  
**Proxy Response Headers:** ❌ No

**Extension Feasibility:** ⭐⭐⭐ (Moderate)
- Would need to monkey-patch `Net::HTTP#connect` method
- The CONNECT request is built internally in `connect.rb`
- Response headers are discarded after checking status code
- Could create a custom subclass or prepend module

**Code Location:** `lib/net/http.rb` - `connect` method

---

### 2. Faraday

**GitHub:** https://github.com/lostisland/faraday  
**Downloads:** ~200M total, most popular HTTP client abstraction

**Proxy Support:**
- Via `f.proxy = proxy_url`
- Uses Net::HTTP adapter by default
- Multiple adapter support (Net::HTTP, Typhoeus, Excon, etc.)

**Custom CONNECT Headers:** ❌ No  
**Proxy Response Headers:** ❌ No

**Extension Feasibility:** ⭐⭐⭐⭐⭐ (Excellent)
- Middleware architecture allows easy extension
- Create a custom middleware that wraps the connection
- Could also create a custom adapter
- Best target for extension due to wide adoption

---

### 3. HTTParty

**GitHub:** https://github.com/jnunemaker/httparty  
**Downloads:** ~250M total, very popular

**Proxy Support:**
- Via `http_proxyaddr`, `http_proxyport`, `http_proxyuser`, `http_proxypass` options
- Uses Net::HTTP internally

**Custom CONNECT Headers:** ❌ No  
**Proxy Response Headers:** ❌ No

**Extension Feasibility:** ⭐⭐⭐⭐ (Good)
- Could monkey-patch `HTTParty::ConnectionAdapter`
- Creates `Net::HTTP` instances, could inject custom connection logic
- Module inclusion pattern would work well

---

### 4. RestClient

**GitHub:** https://github.com/rest-client/rest-client  
**Downloads:** ~150M total

**Proxy Support:**
- Via `RestClient.proxy = url` or `HTTPS_PROXY` env var
- Uses Net::HTTP internally

**Custom CONNECT Headers:** ❌ No  
**Proxy Response Headers:** ❌ No

**Extension Feasibility:** ⭐⭐⭐ (Moderate)
- Wraps Net::HTTP, so extending Net::HTTP would cascade
- Could also patch `RestClient::Request#net_http_object`

---

### 5. Typhoeus (libcurl wrapper)

**GitHub:** https://github.com/typhoeus/typhoeus  
**Downloads:** ~100M total

**Proxy Support:**
- Via `proxy: 'url'` option
- Uses libcurl under the hood (Ethon FFI bindings)

**Custom CONNECT Headers:** ⚠️ Potentially (via Ethon)  
**Proxy Response Headers:** ⚠️ Potentially (via header_function)

**Extension Feasibility:** ⭐⭐⭐⭐⭐ (Excellent)
- libcurl supports `CURLOPT_PROXYHEADER` (since 7.37.0)
- Ethon (FFI wrapper) may need extension to expose this option
- `header_function` callback could capture proxy response
- **Best native potential** due to libcurl's full support

**Key Functions:**
- `Ethon::Easy#proxyheader=` (would need to add)
- `CURLOPT_HEADERFUNCTION` for response parsing

---

### 6. HTTP.rb (http gem)

**GitHub:** https://github.com/httprb/http  
**Downloads:** ~60M total

**Proxy Support:**
- Via `HTTP.via(host, port, user, pass).get(url)`
- Custom socket handling

**Custom CONNECT Headers:** ❌ No  
**Proxy Response Headers:** ❌ No

**Extension Feasibility:** ⭐⭐⭐⭐ (Good)
- Clean architecture with `HTTP::Connection` class
- `HTTP::Timeout::PerOperation` handles connection
- Could extend `HTTP::Connection` to inject CONNECT headers
- Response headers would need socket read modification

---

### 7. Excon

**GitHub:** https://github.com/excon/excon  
**Downloads:** ~100M total

**Proxy Support:**
- Via `proxy: 'url'` option
- Handles CONNECT internally

**Custom CONNECT Headers:** ❌ No  
**Proxy Response Headers:** ❌ No

**Extension Feasibility:** ⭐⭐⭐⭐ (Good)
- `Excon::Connection` handles proxying
- `setup_proxy` and `connect_proxy` methods are extension points
- Middleware support via interceptors

---

### 8. HTTPClient

**GitHub:** https://github.com/nahi/httpclient  
**Downloads:** ~50M total

**Proxy Support:**
- Via `HTTPClient.new(proxy_url)`
- Advanced proxy configuration

**Custom CONNECT Headers:** ❌ No  
**Proxy Response Headers:** ❌ No

**Extension Feasibility:** ⭐⭐⭐ (Moderate)
- `HTTPClient::Session` handles connection
- More complex internal structure
- Would need to patch `do_connect` method

---

### 9. Mechanize

**GitHub:** https://github.com/sparklemotion/mechanize  
**Downloads:** ~50M total

**Proxy Support:**
- Via `agent.set_proxy(host, port, user, pass)`
- Uses Net::HTTP internally

**Custom CONNECT Headers:** ❌ No  
**Proxy Response Headers:** ❌ No

**Extension Feasibility:** ⭐⭐⭐ (Moderate)
- Wraps Net::HTTP, extending Net::HTTP would cascade
- Better to provide a custom HTTP agent

---

### 10. Patron (libcurl wrapper)

**GitHub:** https://github.com/toland/patron  
**Downloads:** ~15M total

**Proxy Support:**
- Via `session.proxy = url`
- Uses libcurl via C extension

**Custom CONNECT Headers:** ⚠️ Potentially  
**Proxy Response Headers:** ⚠️ Potentially

**Extension Feasibility:** ⭐⭐⭐ (Moderate)
- C extension would need modification
- Less flexible than Typhoeus/Ethon FFI approach

---

## Summary Table

| Library | Proxy Support | Custom CONNECT Headers | Proxy Response Headers | Extension Feasibility |
|---------|--------------|----------------------|----------------------|---------------------|
| Net::HTTP | ✅ | ❌ | ❌ | ⭐⭐⭐ |
| Faraday | ✅ | ❌ | ❌ | ⭐⭐⭐⭐⭐ |
| HTTParty | ✅ | ❌ | ❌ | ⭐⭐⭐⭐ |
| RestClient | ✅ | ❌ | ❌ | ⭐⭐⭐ |
| Typhoeus | ✅ | ⚠️ Possible | ⚠️ Possible | ⭐⭐⭐⭐⭐ |
| HTTP.rb | ✅ | ❌ | ❌ | ⭐⭐⭐⭐ |
| Excon | ✅ | ❌ | ❌ | ⭐⭐⭐⭐ |
| HTTPClient | ✅ | ❌ | ❌ | ⭐⭐⭐ |
| Mechanize | ✅ | ❌ | ❌ | ⭐⭐⭐ |
| Patron | ✅ | ⚠️ Possible | ⚠️ Possible | ⭐⭐⭐ |

## Recommended Implementation Priority

### Phase 1: Core Foundation
1. **Net::HTTP extension** - Core module that other libraries can leverage
2. **Faraday middleware** - Widest reach due to adapter pattern

### Phase 2: Direct Library Support
3. **Typhoeus/Ethon** - Best native support potential via libcurl
4. **HTTParty** - Very popular, easy win
5. **HTTP.rb** - Clean architecture

### Phase 3: Additional Libraries
6. **Excon** - Common in cloud environments (AWS SDK)
7. **RestClient** - Still widely used
8. **HTTPClient** - Enterprise usage

## Technical Approach

### For Net::HTTP-based libraries
Create a monkey-patch module that:
1. Overrides `Net::HTTP#connect` to inject custom CONNECT headers
2. Captures and stores proxy response headers before TLS upgrade
3. Provides accessor methods for proxy headers

### For Typhoeus/libcurl
Extend Ethon to expose:
1. `CURLOPT_PROXYHEADER` for sending custom headers
2. Custom `CURLOPT_HEADERFUNCTION` to capture CONNECT response

### For Faraday
Create middleware that:
1. Wraps the connection with proxy header support
2. Stores proxy response headers in the `env` object
3. Works with any underlying adapter that supports proxy
