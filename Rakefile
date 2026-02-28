# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: %i[spec rubocop]

desc 'Run tests with verbose output'
task :test do
  sh 'bundle exec rspec --format documentation'
end

desc 'Generate YARD documentation'
task :doc do
  sh 'bundle exec yard doc'
end
