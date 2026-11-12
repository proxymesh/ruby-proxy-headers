# frozen_string_literal: true

require 'date'
require 'English'
require 'json'
require 'net/http'
require 'open3'
require 'rubygems/package'
require 'tmpdir'

# Prepares a release checkout and checks the version manifests.
# One script, so it is longer than RuboCop's library module limit.
# rubocop:disable Metrics/ModuleLength
module GemRelease
  SEMVER = '(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
  VERSION_RE = Regexp.new("\\A#{SEMVER}\\z").freeze
  RELEASE_REF_RE = Regexp.new("\\Arelease/#{SEMVER}\\z").freeze
  TAG_RE = Regexp.new("\\Av#{SEMVER}\\z").freeze
  REPO_RE = %r{\A[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\z}
  VERSION_FILE = 'lib/ruby_proxy_headers/version.rb'
  GEM_NAME = 'ruby-proxy-headers'

  class Error < StandardError
  end

  USAGE = 'usage: release.rb version|bump|check|check-branch|notes|gate|plan|push-gem|github-release'

  COMMANDS = {
    'version' => ->(*) { puts read_version },
    'bump' => ->(argv) { bump(argv[1]) },
    'check' => ->(argv) { run_check(argv.drop(1)) },
    'check-branch' => ->(*) { check_branch },
    'notes' => ->(argv) { print changelog_notes(required_version(argv[1])) },
    'gate' => ->(*) { gate },
    'plan' => ->(*) { plan },
    'push-gem' => ->(*) { push_gem },
    'github-release' => ->(*) { github_release }
  }.freeze

  def self.run(argv)
    command = COMMANDS[argv.first]
    return command.call(argv) if command

    warn USAGE
    exit 1
  rescue Error => e
    warn e.message
    exit 1
  end

  def self.read_version
    match = File.read(VERSION_FILE).match(/^\s*VERSION = ['"]([^'"]+)['"]/)
    version = match && match[1]
    raise Error, "#{VERSION_FILE} has no MAJOR.MINOR.PATCH VERSION" unless version&.match?(VERSION_RE)

    version
  end

  def self.bump(spec)
    spec = spec.to_s.strip
    current = read_version
    version = bump_number(current, spec).join('.')
    write_version(version)
    write_lock(current, version)
    write_changelog(current, version, Time.now.utc.strftime('%Y-%m-%d'))
    warn "Release #{version}"
    emit('version', version)
  end

  def self.run_check(argv)
    options = { expected: nil, require_changelog: false, gem_path: nil }
    parse_check_arg(options, argv) until argv.empty?
    check(**options)
  end

  def self.parse_check_arg(options, argv)
    arg = argv.shift
    case arg
    when '--version' then options[:expected] = required_version(argv.shift)
    when '--require-changelog' then options[:require_changelog] = true
    when '--gem' then options[:gem_path] = argv.shift
    else raise Error, "unknown argument #{arg}"
    end
    raise Error, '--gem needs a path' if arg == '--gem' && options[:gem_path].to_s.empty?
  end

  def self.check(expected: nil, require_changelog: false, gem_path: nil)
    version = read_version
    assert_lock(version)
    raise Error, "version is #{version}, expected #{expected}" if expected && expected != version

    assert_changelog(version) if require_changelog
    assert_gem(version, gem_path) if gem_path
  end

  def self.check_branch
    return unless ENV.fetch('GITHUB_EVENT_NAME') == 'pull_request'

    ref = ENV.fetch('GITHUB_HEAD_REF', '')
    return unless ref.start_with?('release/')

    match = ref.match(RELEASE_REF_RE)
    raise Error, 'release branch must be release/X.Y.Z' unless match

    check(expected: version_from(match), require_changelog: true)
  end

  def self.gate
    case ENV.fetch('GITHUB_EVENT_NAME')
    when 'push' then gate_push
    when 'release' then gate_tag
    else raise Error, "unexpected event #{ENV.fetch('GITHUB_EVENT_NAME')}"
    end
  end

  def self.plan
    action, create, message = plan_action(plan_state)
    warn message if message
    emit('action', action)
    emit('create_release', create ? 'true' : 'false')
  end

  def self.plan_state
    version = required_version(ENV.fetch('VERSION'))
    tag = "v#{version}"
    {
      mode: ENV.fetch('MODE'),
      version: version,
      gem_exists: gem_published?(version),
      release_exists: release_exists?(tag),
      tag_sha: tag_commit(tag),
      head_sha: ENV.fetch('TARGET_SHA')
    }
  end

  def self.push_gem
    version = required_version(ENV.fetch('VERSION'))
    path = "#{GEM_NAME}-#{version}.gem"
    raise Error, "#{path} was not built" unless File.file?(path)

    stdout, stderr, status = Open3.capture3('gem', 'push', path)
    return if status.success?
    return if "#{stdout}\n#{stderr}".match?(/already exists|Repushing|same version/i)

    warn stdout
    warn stderr
    raise Error, "gem push failed for #{version}"
  end

  def self.github_release
    version = required_version(ENV.fetch('VERSION'))
    tag = "v#{version}"
    return warn("GitHub Release #{tag} already exists.") if release_exists?(tag)

    notes = File.join(Dir.tmpdir, 'release-notes.md')
    File.write(notes, release_notes(version))
    create_release(tag, notes)
  end

  def self.create_release(tag, notes)
    _stdout, stderr, status = Open3.capture3(
      'gh', 'release', 'create', tag, '--repo', repository,
      '--target', ENV.fetch('TARGET_SHA'), '--title', tag, '--notes-file', notes
    )
    return if status.success?

    warn stderr
    raise Error, "could not create GitHub Release #{tag}"
  end

  def self.changelog_notes(version)
    lines = File.readlines('CHANGELOG.md')
    start = lines.index { |line| dated_heading?(line, version) }
    raise Error, "CHANGELOG.md has no dated #{version} section" unless start

    rest = lines[(start + 1)..] || []
    stop = rest.index { |line| section_boundary?(line) }
    body = stop ? rest[0...stop] : rest
    "#{([lines[start]] + body).join.strip}\n"
  end

  def self.plan_action(state)
    same = !state[:tag_sha].empty? && state[:tag_sha] == state[:head_sha]
    return gem_already_published(state, same) if state[:gem_exists]
    raise Error, "GitHub Release v#{state[:version]} does not point at this commit" if misplaced_release?(state, same)

    ['push', state[:mode] == 'release', nil]
  end

  def self.misplaced_release?(state, same)
    state[:mode] == 'release' && state[:release_exists] && !same && !state[:tag_sha].empty?
  end

  def self.gem_already_published(state, same)
    version = state[:version]
    done = ['already_done', false, "#{version} is already published for this commit"]
    return done if state[:release_exists] && same

    if !state[:tag_sha].empty? && !same
      raise Error, "#{version} is already on RubyGems at #{state[:tag_sha]}. Refusing to push it again."
    end

    return ['release_only', true, nil] if state[:mode] == 'release'

    raise Error, "#{version} is already on RubyGems. Refusing to push it again."
  end

  def self.bump_number(current, spec)
    major, minor, patch = current.split('.').map(&:to_i)
    case spec
    when 'patch' then [major, minor, patch + 1]
    when 'minor' then [major, minor + 1, 0]
    when 'major' then [major + 1, 0, 0]
    else
      raise Error, "#{spec} is not a newer X.Y.Z, patch, minor, or major" unless newer?(spec, current)

      spec.split('.').map(&:to_i)
    end
  end

  def self.newer?(spec, current)
    return false unless spec.match?(VERSION_RE)

    (spec.split('.').map(&:to_i) <=> current.split('.').map(&:to_i)) == 1
  end

  def self.write_version(version)
    updated = File.read(VERSION_FILE).sub(/^(\s*VERSION = )['"][^'"]*['"]/, "\\1'#{version}'")
    raise Error, "could not update #{VERSION_FILE}" if updated == File.read(VERSION_FILE)

    File.write(VERSION_FILE, updated)
  end

  def self.write_lock(old_version, new_version)
    count = 0
    pattern = /^(\s*#{GEM_NAME} \()#{Regexp.escape(old_version)}(\).*)$/
    updated = File.read('Gemfile.lock').gsub(pattern) do
      count += 1
      "#{Regexp.last_match(1)}#{new_version}#{Regexp.last_match(2)}"
    end
    raise Error, 'Gemfile.lock has no ruby-proxy-headers version to update' if count.zero?

    File.write('Gemfile.lock', updated)
  end

  def self.write_changelog(old_version, version, date)
    lines, start, finish = split_unreleased(File.read('CHANGELOG.md'))
    text = replace_unreleased(lines, start, finish, version, date)
    File.write('CHANGELOG.md', rewrite_links(text, old_version, version))
  end

  def self.split_unreleased(text)
    lines = text.lines
    start = lines.index { |line| line.strip == '## [Unreleased]' }
    raise Error, 'CHANGELOG.md has no ## [Unreleased] section' unless start

    offset = lines[(start + 1)..].index { |line| section_boundary?(line) }
    finish = offset ? start + 1 + offset : lines.size
    [lines, start, finish]
  end

  def self.replace_unreleased(lines, start, finish, version, date)
    body = lines[(start + 1)...finish].join.strip
    section = "## [Unreleased]\n\n## [#{version}] - #{date}\n"
    section += "\n#{body}\n" unless body.empty?
    lines[start...finish] = ["#{section}\n"]
    lines.join
  end

  def self.rewrite_links(text, old_version, version)
    lines = text.lines
    replace_link(lines, '[Unreleased]:', "[Unreleased]: https://github.com/#{repository}/compare/v#{version}...HEAD\n")
    place_version_link(lines, version, old_version)
    lines.join
  end

  def self.replace_link(lines, prefix, replacement)
    index = lines.index { |line| line.start_with?(prefix) }
    index ? lines[index] = replacement : lines << replacement
  end

  def self.place_version_link(lines, version, old_version)
    prefix = "[#{version}]:"
    replacement = "#{prefix} https://github.com/#{repository}/compare/v#{old_version}...v#{version}\n"
    index = lines.index { |line| line.start_with?(prefix) }
    return lines[index] = replacement if index

    after = lines.index { |line| line.start_with?('[Unreleased]:') }
    after ? lines.insert(after + 1, replacement) : lines << replacement
  end

  def self.gate_push
    event = JSON.parse(File.read(ENV.fetch('GITHUB_EVENT_PATH')))
    sha = ENV.fetch('GITHUB_SHA')
    version = choose_release(pulls(sha), event.dig('head_commit', 'message').to_s)
    emit('publish', version ? 'true' : 'false')
    return unless version

    emit('version', version)
    emit('sha', sha)
    emit('mode', 'release')
  end

  def self.gate_tag
    match = ENV.fetch('GITHUB_REF_NAME').match(TAG_RE)
    raise Error, 'release tag must be vX.Y.Z' unless match

    emit('publish', 'true')
    emit('version', version_from(match))
    emit('sha', ENV.fetch('GITHUB_SHA'))
    emit('mode', 'gem')
  end

  def self.choose_release(pulls, message)
    versions = pulls.filter_map { |pull| release_version(pull) }
    raise Error, "commit is in more than one release pull request: #{versions.join(', ')}" if versions.size > 1
    return versions.first if versions.any?

    return nil unless release_message?(message)

    raise Error, 'commit looks like a release merge, but no release pull request is attached to it'
  end

  def self.release_version(pull)
    return unless pull['merged_at'] || pull['merged'] == true
    return unless pull.dig('base', 'ref') == 'main'

    match = pull.dig('head', 'ref').to_s.match(RELEASE_REF_RE)
    version_from(match) if match
  end

  def self.release_message?(text)
    text.match?(%r{from \S+/release/#{SEMVER}}) || text.match?(/\ARelease #{SEMVER}\b/)
  end

  def self.pulls(sha)
    stdout, status = Open3.capture2('gh', 'api', "repos/#{repository}/commits/#{sha}/pulls")
    raise Error, 'could not list pull requests for this commit' unless status.success?

    parsed = JSON.parse(stdout)
    raise Error, 'could not list pull requests for this commit' unless parsed.is_a?(Array)

    parsed
  end

  def self.gem_published?(version)
    uri = URI("https://rubygems.org/api/v2/rubygems/#{GEM_NAME}/versions/#{version}.json")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) do |http|
      http.get(uri.request_uri)
    end
    return true if response.code == '200'
    return false if response.code == '404'

    raise Error, "RubyGems returned HTTP #{response.code} for #{version}"
  end

  def self.tag_commit(tag)
    stdout, status = Open3.capture2('git', 'rev-parse', '--verify', "#{tag}^{commit}")
    status.success? ? stdout.strip : ''
  end

  def self.release_exists?(tag)
    _stdout, status = Open3.capture2('gh', 'release', 'view', tag, '--repo', repository)
    status.success?
  end

  def self.release_notes(version)
    return changelog_notes(version) if File.readlines('CHANGELOG.md').any? { |line| dated_heading?(line, version) }

    "Release #{version}.\n"
  end

  def self.assert_lock(version)
    found = File.readlines('Gemfile.lock').filter_map { |line| line[/^\s*#{GEM_NAME} \(([^)]+)\)/, 1] }
    raise Error, 'Gemfile.lock has no ruby-proxy-headers version' if found.empty?
    return if found.uniq == [version]

    raise Error, "Gemfile.lock has #{found.uniq.join(', ')}, #{VERSION_FILE} has #{version}"
  end

  def self.assert_changelog(version)
    return if File.readlines('CHANGELOG.md').any? { |line| dated_heading?(line, version) }

    raise Error, "CHANGELOG.md has no ## [#{version}] - YYYY-MM-DD section"
  end

  def self.assert_gem(version, path)
    expected = "#{GEM_NAME}-#{version}.gem"
    raise Error, "#{File.basename(path)} is not #{expected}" unless File.basename(path) == expected

    built = Gem::Package.new(path).spec.version.to_s
    return if built == version

    raise Error, "built gem is #{built}, expected #{version}"
  end

  def self.dated_heading?(line, version)
    match = line.strip.match(/\A## \[#{Regexp.escape(version)}\] - (\d{4}-\d{2}-\d{2})\z/)
    return false unless match

    Date.iso8601(match[1])
    true
  rescue ArgumentError
    false
  end

  def self.section_boundary?(line)
    line.start_with?('## ') || line.match?(/\A\[[^\]]+\]:/)
  end

  def self.required_version(value)
    raise Error, 'version must be X.Y.Z' unless value.to_s.match?(VERSION_RE)

    value
  end

  def self.version_from(match)
    "#{match[1]}.#{match[2]}.#{match[3]}"
  end

  def self.repository
    repo = ENV['GITHUB_REPOSITORY'].to_s
    return repo if repo.match?(REPO_RE)

    raise Error, 'GITHUB_REPOSITORY is not set'
  end

  def self.emit(key, value)
    puts "#{key}=#{value}"
    path = ENV.fetch('GITHUB_OUTPUT', '')
    return if path.empty?

    File.open(path, 'a') { |file| file.puts "#{key}=#{value}" }
  end
end
# rubocop:enable Metrics/ModuleLength

GemRelease.run(ARGV) if $PROGRAM_NAME == __FILE__
