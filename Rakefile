require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << "lib"
  t.test_files = FileList['test/tc_*.rb']
  t.verbose = true
end

task :clean do
  sh 'rm -f *.gem'
end

task :build do
  sh 'gem build *.gemspec' if Dir.glob('*.gem').empty?
end

task :install => [:build] do
  system 'gem uninstall foreman_hook-host_rename >/dev/null 2>&1'
  sh 'gem install --bindir=/usr/bin --no-rdoc --no-ri *.gem'
  sh 'gem contents foreman_hook-host_rename'
end

task :deploy do
  sh "rake clean build"
  sh "sudo scl enable ruby193 'rake install'"
  sh "sudo scl enable ruby193 '/usr/bin/foreman_hook-host_rename --install'"
end
