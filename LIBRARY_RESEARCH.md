# Ruby library proxy header support (CONNECT tunnel)

This document analyzes the Ruby HTTP / scraping stack used in [proxy-examples](https://github.com/proxymesh/proxy-examples/tree/main/ruby) for **custom headers on HTTPS `CONNECT`** and **reading the proxy `CONNECT` response headers**.

## Executive summary

| Library | Native CONNECT header API | Extension approach |
|---------|---------------------------|---------------------|
| **Net::HTTP** (stdlib) | No — tunnel is hard-coded in `#connect` | **Implemented:** prepend patch; optional `proxy_connect_request_headers`; `last_proxy_connect_response_headers` |
| **Faraday** | No — delegates to adapters (`net_http`, etc.) | **High:** use patched `Net::HTTP` with `Faraday.new(connection_options)` or custom adapter that sets `proxy_connect_request_headers` |
| **HTTParty** | No — built on `Net::HTTP` | **High:** global or per-class `Net::HTTP` instances after `patch!`; or subclass `Connection` if needed |
| **Mechanize** | No — uses `Net::HTTP` / persistent connections internally | **Medium–high:** ensure Mechanize’s internal HTTP object gets the same patched behavior and header accessors |
| **Excon** | **Send:** yes — `:ssl_proxy_headers` on connection. **Read CONNECT response:** not exposed on origin `Excon::Response` | **Partial:** use `:ssl_proxy_headers` for sends; reading `X-ProxyMesh-IP` from CONNECT needs upstream Excon changes (see [DEFERRED.md](DEFERRED.md)) |
| **Typhoeus / Ethon** | **Send and read:** `:proxyheader` and `:headeropt` since Ethon 0.19 / Typhoeus 1.7 | **Implemented:** `RubyProxyHeaders::Typhoeus` sets `headeropt: :separate` and parses the CONNECT block from `response_headers` |
| **Nokogiri** | N/A (XML/HTML parser only) | **N/A** — proxying is whatever HTTP client fetches the document (usually `Net::HTTP`) |

As with Node and Python stacks, most high-level Ruby clients do not expose a first-class “proxy CONNECT request/response headers” API. Extensions hook **below** the HTTP library (stdlib `Net::HTTP`), **inside** Faraday’s adapter, or **at** the libcurl / Excon layer. Typhoeus 1.7 / Ethon 0.19 is used directly via `:proxyheader`.

## Connection flow (HTTPS over HTTP proxy)

```
Client -- CONNECT + custom headers --> Proxy
Client <-- CONNECT response headers --- Proxy
Client === TLS tunnel =================> Origin
```

## Net::HTTP (stdlib)

MRI implements the tunnel in `Net::HTTP#connect` (see `net/http.rb`): it writes `CONNECT host:port`, `Host`, optional `Proxy-Authorization`, then reads the response with `Net::HTTPResponse.read_new` and calls `#value` without exposing headers to callers.

**Feasibility:** High — same pattern as Python’s `HTTPSConnection._tunnel` override in `python-proxy-headers`.

## Faraday

Uses adapters; default `net_http` adapter constructs `Net::HTTP`. If `Net::HTTP` is patched and exposes `proxy_connect_request_headers`, Faraday can pass options through `connection` / `request` options in a thin wrapper.

**Feasibility:** High once `Net::HTTP` support is stable.

## HTTParty

Uses `Net::HTTP` under the hood for sync requests. After `RubyProxyHeaders::NetHTTP.patch!`, new `Net::HTTP` objects support the new accessors.

**Feasibility:** High — may need documented patterns for `default_options` and connection lifecycle.

## Mechanize

Builds on `net/http` (often `net-http-persistent`). May require verifying that the patched `connect` runs for its connections and that response/header capture is visible on the right object.

**Feasibility:** Medium.

## Excon

Own implementation of proxy and TLS; does not use `Net::HTTP#connect`.

**Feasibility:** Medium — requires a dedicated Excon middleware or socket layer similar to the JavaScript core agent.

## Typhoeus / Ethon (libcurl)

**Status:** Implemented for Typhoeus 1.7+ / Ethon 0.19+.

Ethon maps `CURLOPT_PROXYHEADER` to `:proxyheader` and `CURLOPT_HEADEROPT` to `:headeropt` (`:unified` / `:separate`). `RubyProxyHeaders::Typhoeus` puts caller proxy headers on that list with `:separate`, so CONNECT does not also receive application headers. The CONNECT response, including `X-ProxyMesh-IP`, is the first header block of `response_headers` and is exposed as `proxy_response_headers`. There is no runtime gem dependency; applications install `typhoeus` ~> 1.7 themselves. libcurl 7.37 or newer is required.

## Nokogiri

Parsing only; no network layer.

**Feasibility:** N/A — combine with `Net::HTTP` + patch or another extended client.

---

*Last updated: October 2026*
