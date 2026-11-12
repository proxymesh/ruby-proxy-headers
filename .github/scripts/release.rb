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
    when 'notes' then print notes(argv[1])
    else warn 'usage: release.rb bump SPEC|notes X.Y.Z'
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
    write_changelog(current, version, Time.now.utc.strftime('%Y-%m-%d'))
    append_output(version)
  end

  def self.notes(version)
    raise Error, 'version must be X.Y.Z' unless version.to_s.match?(VERSION_RE)

    lines = File.readlines('CHANGELOG.md')
    start = heading_index(lines, version)
    raise Error, "CHANGELOG.md has no dated #{version} section" unless start

    slice_section(lines, start)
  end

  def self.heading_index(lines, version)
    pattern = /\A## \[#{Regexp.escape(version)}\] - \d{4}-\d{2}-\d{2}\z/
    lines.index { |line| line.strip.match?(pattern) }
  end

  def self.slice_section(lines, start)
    rest = lines[(start + 1)..] || []
    stop = rest.index { |line| line.start_with?('## ') || line.match?(/\A\[[^\]]+\]:/) }
    "#{([lines[start]] + (stop ? rest[0...stop] : rest)).join.strip}\n"
  end

  def self.read_version
    match = File.read(VERSION_FILE).match(/^\s*VERSION = ['"]([^'"]+)['"]/)
    version = match && match[1]
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
    count = 0
    pattern = /^(\s*ruby-proxy-headers \()#{Regexp.escape(old_version)}(\).*)$/
    updated = File.read('Gemfile.lock').gsub(pattern) do
      count += 1
      "#{Regexp.last_match(1)}#{new_version}#{Regexp.last_match(2)}"
    end
    raise Error, 'Gemfile.lock has no ruby-proxy-headers version' if count.zero?

    File.write('Gemfile.lock', updated)
  end

  def self.write_changelog(old_version, version, date)
    lines, start, finish = unreleased_span(File.read('CHANGELOG.md'))
    body = lines[(start + 1)...finish].join.strip
    heading = "## [Unreleased]\n\n## [#{version}] - #{date}\n"
    heading = "#{heading}\n#{body}\n" unless body.empty?
    lines[start...finish] = ["#{heading}\n"]
    File.write('CHANGELOG.md', with_links(lines.join, old_version, version))
  end

  def self.unreleased_span(text)
    lines = text.lines
    start = lines.index { |line| line.strip == '## [Unreleased]' }
    raise Error, 'CHANGELOG.md has no ## [Unreleased] section' unless start

    offset = lines[(start + 1)..].index { |line| line.start_with?('## ') || line.match?(/\A\[[^\]]+\]:/) }
    [lines, start, offset ? start + 1 + offset : lines.size]
  end

  def self.with_links(text, old_version, version)
    repo = ENV.fetch('GITHUB_REPOSITORY')
    unreleased = "[Unreleased]: https://github.com/#{repo}/compare/v#{version}...HEAD"
    current = "[#{version}]: https://github.com/#{repo}/compare/v#{old_version}...v#{version}"
    text = text.sub(/^\[Unreleased\]:.*$/, unreleased)
    return text if text.include?("#{current}\n")

    text.sub(/(\[Unreleased\]:.*\n)/, "\\1#{current}\n")
  end

  def self.append_output(version)
    path = ENV.fetch('GITHUB_OUTPUT', '')
    File.open(path, 'a') { |file| file.puts "version=#{version}" } unless path.empty?
  end
end

GemRelease.run(ARGV) if $PROGRAM_NAME == __FILE__
