source 'https://rubygems.org'

gemspec

gem 'rake'
gem 'pry'
gem 'simplecov'
gem 'minitest'

# NCBO gems (can be from a local dev path or from rubygems/git)
gemfile_local = File.expand_path("../Gemfile.local", __FILE__)
if File.exists?(gemfile_local)
  self.instance_eval(Bundler.read_file(gemfile_local))
end
