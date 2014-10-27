require 'bundler/gem_tasks'
require 'rake/testtask'

ROOT_DIR = File.dirname(__FILE__)
gemspec = Gem::Specification.load("#{Dir.glob(ROOT_DIR + '/*.gemspec')[0]}")

Rake::TestTask.new do |t|
  t.libs << "lib"
  t.test_files = FileList['test/tc_*.rb']
  t.verbose = true
end

task :install do
  system 'gem uninstall foreman_hook-host_rename >/dev/null 2>&1'
  sh 'gem install --bindir=/usr/bin --no-rdoc --no-ri *.gem'
  sh 'gem contents foreman_hook-host_rename'
end

task :deploy do
  sh "rake clean build"
  sh "sudo scl enable ruby193 'rake install'"
  sh "sudo scl enable ruby193 '/usr/bin/foreman_hook-host_rename --install'"
end
