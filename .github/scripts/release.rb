# frozen_string_literal: true

require 'English'

# Bumps the gem version and prints a changelog section.
module GemRelease
  VERSION_FILE = 'lib/ruby_proxy_headers/version.rb'
  VERSION_RE = /\A(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)\z/

  class Error < StandardError
  end

  def self.run(argv)
    case argv.first
    when 'bump' then bump(argv[1])
    when 'check' then check(argv[1])
    when 'notes' then print notes(argv[1])
    else warn 'usage: release.rb bump SPEC|check [X.Y.Z]|notes X.Y.Z'
         exit 1
    end
  rescue Error => e
    warn e.message
    exit 1
  end

  def self.bump(spec)
    current = read_version
    version = next_version(current, spec.to_s.strip)
    write_version(version)
    write_lock(current, version)
    write_changelog(version, Time.now.utc.strftime('%Y-%m-%d'))
    path = ENV.fetch('GITHUB_OUTPUT', '')
    File.open(path, 'a') { |file| file.puts "version=#{version}" } unless path.empty?
  end

  def self.check(expected = nil)
    version = read_version
    assert_lock(version)
    raise Error, "version is #{version}, expected #{expected}" unless expected.nil? || expected == version

    head = ENV.fetch('HEAD_REF') { ENV.fetch('GITHUB_HEAD_REF', '') }
    assert_branch(head, version)
    notes(version) if head.start_with?('release/') || expected
  end

  def self.assert_branch(head, version)
    return unless head.start_with?('release/')

    raise Error, "branch #{head} does not match #{version}" unless head == "release/#{version}"
  end

  def self.assert_lock(version)
    found = File.readlines('Gemfile.lock').filter_map { |line| line[/^\s*ruby-proxy-headers \(([^)]+)\)/, 1] }
    raise Error, 'Gemfile.lock does not match version.rb' if found.empty? || found.uniq != [version]
  end

  def self.notes(version)
    raise Error, 'version must be X.Y.Z' unless version.to_s.match?(VERSION_RE)

    lines = File.readlines('CHANGELOG.md')
    start = lines.index { |line| line.strip.match?(/\A## #{Regexp.escape(version)} - \d{4}-\d{2}-\d{2}\z/) }
    raise Error, "CHANGELOG.md has no ## #{version} - YYYY-MM-DD section" unless start

    section_body(lines, start)
  end

  def self.section_body(lines, start)
    rest = lines[(start + 1)..] || []
    stop = rest.index { |line| line.start_with?('## ') }
    "#{([lines[start]] + (stop ? rest[0...stop] : rest)).join.strip}\n"
  end

  def self.read_version
    version = File.read(VERSION_FILE)[/^\s*VERSION = ['"]([^'"]+)['"]/, 1]
    raise Error, 'version.rb has no MAJOR.MINOR.PATCH' unless version&.match?(VERSION_RE)

    version
  end

  def self.next_version(current, spec)
    major, minor, patch = current.split('.').map(&:to_i)
    case spec
    when 'patch' then "#{major}.#{minor}.#{patch + 1}"
    when 'minor' then "#{major}.#{minor + 1}.0"
    when 'major' then "#{major + 1}.0.0"
    else
      raise Error, "#{spec} is not a newer X.Y.Z, patch, minor, or major" unless newer?(spec, current)

      spec
    end
  end

  def self.newer?(spec, current)
    spec.match?(VERSION_RE) && (spec.split('.').map(&:to_i) <=> current.split('.').map(&:to_i)) == 1
  end

  def self.write_version(version)
    updated = File.read(VERSION_FILE).sub(/^(\s*VERSION = )['"][^'"]*['"]/, "\\1'#{version}'")
    raise Error, "could not update #{VERSION_FILE}" if updated == File.read(VERSION_FILE)

    File.write(VERSION_FILE, updated)
  end

  def self.write_lock(old_version, new_version)
    pattern = /^(\s*ruby-proxy-headers \()#{Regexp.escape(old_version)}(\).*)$/
    original = File.read('Gemfile.lock')
    updated = original.gsub(pattern) { "#{Regexp.last_match(1)}#{new_version}#{Regexp.last_match(2)}" }
    raise Error, 'Gemfile.lock has no ruby-proxy-headers version' if updated == original

    File.write('Gemfile.lock', updated)
  end

  def self.write_changelog(version, date)
    lines, start, finish = unreleased_bounds
    body = lines[(start + 1)...finish].join.strip
    lines[start...finish] = ["## Unreleased\n\n## #{version} - #{date}\n\n#{body}\n\n"]
    File.write('CHANGELOG.md', lines.join)
  end

  def self.unreleased_bounds
    lines = File.read('CHANGELOG.md').lines
    start = lines.index { |line| line.strip == '## Unreleased' }
    raise Error, 'CHANGELOG.md has no ## Unreleased section' unless start

    offset = lines[(start + 1)..].index { |line| line.start_with?('## ') }
    [lines, start, offset ? start + 1 + offset : lines.size]
  end
end

GemRelease.run(ARGV) if $PROGRAM_NAME == __FILE__
