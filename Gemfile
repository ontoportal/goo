source 'https://rubygems.org'

gemspec

gem "activesupport"
gem "cube-ruby", require: "cube"
gem "rake"
gem "uuid"
gem 'sparql-client', github: 'ncbo/sparql-client', tag: 'v6.3.0'


group :test do
  gem "minitest", '< 5.0'
  gem "pry"
  gem 'simplecov'
  gem 'simplecov-cobertura' # for submitting code coverage results to codecov.io
end

group :profiling do
  gem "rack-accept"
  gem "rack-post-body-to-params"
  gem "sinatra"
  gem "thin"
end

