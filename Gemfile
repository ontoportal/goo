source 'https://rubygems.org'

gemspec

gem 'rake'
gem 'pry'
gem 'simplecov'
gem 'minitest'
gem 'nokogiri'

# Profiling
group :profiling do
  gem 'sinatra'
  gem 'rack-accept'
  gem 'rack-post-body-to-params'
  #gem 'rack-mini-profiler'
  gem 'thin'
end

# NCBO gems (can be from a local dev path or from rubygems/git)
gemfile_local = File.expand_path("../Gemfile.local", __FILE__)
if File.exists?(gemfile_local)
  self.instance_eval(Bundler.read_file(gemfile_local))
end
