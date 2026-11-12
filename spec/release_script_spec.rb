# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'open3'
require 'tmpdir'

RSpec.describe 'release script' do
  it 'bumps a patch and prints the dated changelog section' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/lib/ruby_proxy_headers")
      File.write("#{dir}/lib/ruby_proxy_headers/version.rb", "module RubyProxyHeaders\n  VERSION = '0.2.3'\nend\n")
      File.write("#{dir}/Gemfile.lock", "  ruby-proxy-headers (0.2.3)\n")
      File.write("#{dir}/CHANGELOG.md", "## Unreleased\n\n- Note\n\n## 0.1.0 - 2024-02-28\n\n[Unreleased]: https://github.com/proxymesh/ruby-proxy-headers/compare/v0.1.0...HEAD\n")
      script = File.expand_path('../.github/scripts/release.rb', __dir__)
      env = { 'GITHUB_REPOSITORY' => 'proxymesh/ruby-proxy-headers' }
      _output, status = Open3.capture2e(env, 'ruby', script, 'bump', 'patch', chdir: dir)
      expect(status).to be_success
      expect(File.read("#{dir}/lib/ruby_proxy_headers/version.rb")).to include("VERSION = '0.2.4'")
      notes, notes_status = Open3.capture2e(env, 'ruby', script, 'notes', '0.2.4', chdir: dir)
      expect(notes_status).to be_success
      expect(notes).to include('## 0.2.4 - ')
      _checked, check_status = Open3.capture2e(env, 'ruby', script, 'check', '0.2.4', chdir: dir)
      expect(check_status).to be_success
      expect(notes).to include('- Note')
    end
  end
end
