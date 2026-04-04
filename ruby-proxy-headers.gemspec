# frozen_string_literal: true

require_relative 'lib/ruby_proxy_headers/version'

Gem::Specification.new do |s|
  s.name          = 'ruby-proxy-headers'
  s.version       = RubyProxyHeaders::VERSION
  s.summary       = 'Custom proxy CONNECT headers for Ruby HTTP clients (ProxyMesh, etc.)'
  s.description   = <<~DESC
    Extensions for Ruby HTTP stacks to send custom headers on HTTPS CONNECT to a proxy
    and read headers from the proxy CONNECT response (e.g. X-ProxyMesh-IP).
  DESC
  s.authors       = ['ProxyMesh']
  s.email         = 'support@proxymesh.com'
  s.homepage      = 'https://github.com/proxymesh/ruby-proxy-headers'
  s.license       = 'MIT'
  s.required_ruby_version = '>= 3.1'

  s.metadata['source_code_uri'] = 'https://github.com/proxymesh/ruby-proxy-headers'
  s.metadata['documentation_uri'] = 'https://rubydoc.info/gems/ruby-proxy-headers'

  s.files = Dir['lib/**/*', 'LICENSE', 'README.md', 'IMPLEMENTATION_PRIORITY.md', 'LIBRARY_RESEARCH.md', 'DEFERRED.md', '.yardopts']
  s.require_paths = ['lib']

  s.add_development_dependency 'bundler', '>= 2.4'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rspec', '~> 3.12'
  s.add_development_dependency 'rubocop', '~> 1.50'
  s.add_development_dependency 'yard', '~> 0.9'
  s.add_development_dependency 'excon', '~> 1.4'
  s.add_development_dependency 'faraday', '~> 2.14'
  s.add_development_dependency 'faraday-net_http', '~> 3.4'
  s.add_development_dependency 'httparty', '~> 0.24'
  s.add_development_dependency 'mechanize', '~> 2.14'
  s.add_development_dependency 'typhoeus', '~> 1.6'
end
