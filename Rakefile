# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "cachebar"
  gem.homepage = "http://github.com/vigetlabs/cachebar"
  gem.license = "MIT"
  gem.summary = %Q{A simple API caching layer built on top of HTTParty and Redis}
  gem.description = %Q{A simple API caching layer built on top of HTTParty and Redis}
  gem.email = "brian.landau@viget.com"
  gem.authors = ["Brian Landau", "David Eisinger"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
    test.rcov_opts << '--exclude "gems/*"'
    test.rcov_opts << '--sort coverage'
    test.rcov_opts << '--only-uncovered'
  end
rescue Exception
end

task :default => :test
