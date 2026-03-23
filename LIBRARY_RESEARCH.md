# Ruby library proxy header support (CONNECT tunnel)

This document analyzes the Ruby HTTP / scraping stack used in [proxy-examples](https://github.com/proxymesh/proxy-examples/tree/main/ruby) for **custom headers on HTTPS `CONNECT`** and **reading the proxy `CONNECT` response headers**.

## Executive summary

| Library | Native CONNECT header API | Extension approach |
|---------|---------------------------|---------------------|
| **Net::HTTP** (stdlib) | No — tunnel is hard-coded in `#connect` | **Implemented:** prepend patch; optional `proxy_connect_request_headers`; `last_proxy_connect_response_headers` |
| **Faraday** | No — delegates to adapters (`net_http`, etc.) | **High:** use patched `Net::HTTP` with `Faraday.new(connection_options)` or custom adapter that sets `proxy_connect_request_headers` |
| **HTTParty** | No — built on `Net::HTTP` | **High:** global or per-class `Net::HTTP` instances after `patch!`; or subclass `Connection` if needed |
| **Mechanize** | No — uses `Net::HTTP` / persistent connections internally | **Medium–high:** ensure Mechanize’s internal HTTP object gets the same patched behavior and header accessors |
| **Excon** | No — implements its own proxy tunnel | **Medium:** separate code path (socket write + read CONNECT response), similar to JS `ProxyHeadersAgent` |
| **Typhoeus / Ethon** | Partial — libcurl has proxy options | **Medium:** map headers to `CURLOPT_PROXYHEADER` / related options (libcurl version dependent); capture CONNECT response via callbacks or debug hooks where supported |
| **Nokogiri** | N/A (XML/HTML parser only) | **N/A** — proxying is whatever HTTP client fetches the document (usually `Net::HTTP`) |

As with Node and Python stacks, **none** of the high-level Ruby clients expose a first-class “proxy CONNECT request/response headers” API; extensions must hook **below** the HTTP library (stdlib `Net::HTTP`), **inside** Faraday’s adapter, or **at** the libcurl / Excon layer.

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

libcurl can send additional headers to the proxy; exact options depend on libcurl version (e.g. proxy header lists). CONNECT response header visibility may require `CURLOPT_DEBUGFUNCTION` or version-specific features.

**Feasibility:** Medium — needs research per libcurl version and Ethon API surface.

## Nokogiri

Parsing only; no network layer.

**Feasibility:** N/A — combine with `Net::HTTP` + patch or another extended client.

---

*Last updated: March 2026*
