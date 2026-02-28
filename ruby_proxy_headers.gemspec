# frozen_string_literal: true

require_relative 'lib/ruby_proxy_headers/version'

Gem::Specification.new do |spec|
  spec.name          = 'ruby_proxy_headers'
  spec.version       = RubyProxyHeaders::VERSION
  spec.authors       = ['ProxyMesh']
  spec.email         = ['support@proxymesh.com']

  spec.summary       = 'Send and receive custom proxy headers during HTTPS CONNECT tunneling'
  spec.description   = <<~DESC
    Extensions for Ruby HTTP libraries to support sending custom headers to proxy servers
    during HTTPS CONNECT tunneling and receiving proxy response headers. Essential for
    proxy services like ProxyMesh that use custom headers for country selection and IP assignment.
  DESC
  spec.homepage      = 'https://github.com/proxymeshai/ruby-proxy-headers'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/proxymeshai/ruby-proxy-headers'
  spec.metadata['changelog_uri'] = 'https://github.com/proxymeshai/ruby-proxy-headers/blob/main/CHANGELOG.md'
  spec.metadata['documentation_uri'] = 'https://ruby-proxy-headers.readthedocs.io/'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      f.start_with?('spec/', 'test/', 'features/', '.git', '.github', 'Gemfile')
    end
  end
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'excon', '~> 0.110'
  spec.add_development_dependency 'faraday', '~> 2.9'
  spec.add_development_dependency 'http', '~> 5.2'
  spec.add_development_dependency 'httparty', '~> 0.21'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rest-client', '~> 2.1'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.add_development_dependency 'rubocop', '~> 1.60'
  spec.add_development_dependency 'typhoeus', '~> 1.4'
  spec.add_development_dependency 'webmock', '~> 3.23'
end
