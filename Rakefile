require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/tc_*.rb']
  t.verbose = true
end

task :install do
  prefix = File.dirname(__FILE__)
  hookdir = '/usr/share/foreman/config/hooks/host/managed'
  raise "hook directory not found: #{hookdir}" unless File.exist? hookdir
  raise 'FIXME - TODO'
end