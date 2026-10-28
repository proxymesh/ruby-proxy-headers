# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `RubyProxyHeaders::Typhoeus` sends proxy headers with libcurl `CURLOPT_PROXYHEADER` (`:proxyheader` and `headeropt: :separate` on Typhoeus 1.7 / Ethon 0.19) and exposes the CONNECT response, including `X-ProxyMesh-IP`, as `proxy_response_headers`. Those headers are parsed from the first block of `response_headers`. Typhoeus's `response.headers` stays the origin response.

### Changed

- Development dependencies are now `typhoeus` `~> 1.7` and `ethon` `~> 0.19`. The gem still has no runtime dependency on Typhoeus; applications that use the adapter should add `gem 'typhoeus', '~> 1.7'`.

### Fixed

- HTTPS requests through `RubyProxyHeaders::Typhoeus` no longer call `RubyProxyHeaders::NetHTTP.request`, which is not defined.

## [0.1.0] - 2024-02-28

### Added

- Initial release
- Core `Connection` class for proxy CONNECT handling with custom headers
- `NetHTTP` module for Net::HTTP integration
- `Faraday` middleware for Faraday integration
- `HTTParty` module for HTTParty integration
- `HTTPGem` module for HTTP.rb integration
- `Typhoeus` module for Typhoeus integration
- `Excon` module for Excon integration
- `RestClient` module for RestClient integration
- Comprehensive documentation
- Test suite with RSpec

[Unreleased]: https://github.com/proxymeshai/ruby-proxy-headers/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/proxymeshai/ruby-proxy-headers/releases/tag/v0.1.0
