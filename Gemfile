source 'https://rubygems.org'

gemspec

gem 'rake'
gem 'pry'
gem 'simplecov'
gem 'minitest', '< 5.0'
gem 'activesupport'
gem "uuid"
gem 'cube-ruby', require: "cube"

# Profiling
group :profiling do
  gem 'sinatra'
  gem 'rack-accept'
  gem 'rack-post-body-to-params'
  #gem 'rack-mini-profiler'
  gem 'thin'
end

# NCBO Dependencies
ncbo_branch = ENV["NCBO_BRANCH"] || `git rev-parse --abbrev-ref HEAD`.strip || "staging"
gem 'sparql-client', github: 'ncbo/sparql-client', branch: ncbo_branch
