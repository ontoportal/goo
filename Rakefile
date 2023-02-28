require 'rake/testtask'

task default: %w[test]

Rake::TestTask.new do |t|
  t.libs = []
  t.test_files = FileList['test/test*.rb'].select { |x| !x["index"] }
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:persistence"
  t.test_files = FileList['test/test_basic_persistence.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:cache"
  t.test_files = FileList['test/test_cache.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:chunks_write"
  t.test_files = FileList['test/test_chunks_write.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:collections"
  t.test_files = FileList['test/test_collections.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:dsl_settings"
  t.test_files = FileList['test/test_dsl_settings.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:enum"
  t.test_files = FileList['test/test_enum.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:index"
  t.test_files = FileList['test/test_index.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:inmutable"
  t.test_files = FileList['test/test_inmutable.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:inverse"
  t.test_files = FileList['test/test_inverse.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:model_complex"
  t.test_files = FileList['test/test_model_complex.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:name_with"
  t.test_files = FileList['test/test_name_with.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:namespaces"
  t.test_files = FileList['test/test_namespaces.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:read_only"
  t.test_files = FileList['test/test_read_only.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:schemaless"
  t.test_files = FileList['test/test_schemaless.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:search"
  t.test_files = FileList['test/test_search.rb']
  t.warning = false
end

Rake::TestTask.new do |t|
  t.name = "test:where"
  t.test_files = FileList['test/test_where.rb']
  t.warning = false
end

desc "Console for working with data"
task :console do
  require_relative "test/test_case"
  binding.pry
end

desc "Run test coverage analysis"
task :coverage do
  puts "Code coverage reports will be visible in the /coverage folder"
  ENV["COVERAGE"] = "true"
  Rake::Task["test"].invoke
end

