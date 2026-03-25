# Deferred / not fully supported

## Typhoeus / Ethon

**Status:** Not implemented in this gem.

[Ethon](https://github.com/typhoeus/ethon) does not expose `CURLOPT_PROXYHEADER` (or equivalent) in its `Ethon::Easy` option mapping as of ethon 0.18.x. Adding CONNECT response header capture would require Ethon/libcurl changes or a custom C extension.

**Workaround:** Use `Net::HTTP` + {RubyProxyHeaders::NetHTTP.patch!} or Faraday with `ruby_proxy_headers_net_http` adapter.

---

## Mechanize

**Status:** Not implemented.

[Mechanize](https://github.com/sparklemotion/mechanize) uses [net-http-persistent](https://github.com/drbrain/net-http-persistent), which maintains its own connection layer on top of `Net::HTTP`. Our prepend patch targets `Net::HTTP#connect` on instances Mechanize creates, but verifying header propagation and lifecycle across the persistent pool needs dedicated work.

**Workaround:** Use patched `Net::HTTP` or Faraday for fetches; use Mechanize only when custom CONNECT headers are not required.

---

## Excon — reading CONNECT response headers

**Status:** Sending extra CONNECT headers is supported upstream via `:ssl_proxy_headers`.

Excon’s public `Excon::Response` for the **origin** request does **not** include headers from the proxy’s `CONNECT` response (only the tunneled HTTPS response headers). Capturing `X-ProxyMesh-IP` from CONNECT would require patching Excon internals or a fork.

**Workaround:** Use Net::HTTP / Faraday integrations in this gem, which merge CONNECT headers into the client response where applicable.
