require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs = []
  t.test_files = FileList['test/**/test*.rb']
end

Rake::TestTask.new do |t|
  t.libs = []
  t.name = "test:model"
  t.test_files = FileList['test/**/test_model*.rb']
end

Rake::TestTask.new do |t|
  t.libs = []
  t.name = "test:anon"
  t.test_files = FileList['test/**/test_model_bnode*.rb']
end
