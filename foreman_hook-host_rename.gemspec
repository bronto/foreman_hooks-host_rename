#require File.expand_path("../lib/newgem/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "foreman_hook-host_rename"
  s.version     = '0.0.2'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mark Heily", "Bronto Software, Inc."]
  s.email       = ["mark.heily@bronto.com"]
  s.homepage    = "https://github.com/bronto/foreman_hook-host_rename"
  s.summary     = "Foreman hook that fires when a host is renamed"
  s.description = "See the README for details"

  # Dependencies
  s.required_ruby_version = '>= 1.9.3'
  %w(minitest json sqlite3 rest_client kwalify).each do |dep| 
    s.add_runtime_dependency dep
  end

  # If you need to check in files that aren't .rb files, add them here
  s.files        = Dir[
	"conf/{schema.yaml,settings.yaml.EXAMPLE}", "db/.gitignore",
	"LICENSE", "*.md", "Gemfile", "Gemfile.lock", "*.gemspec",
	] + Dir.glob("{bin,lib}/**/*")
  s.require_path = 'lib'

  s.executables = ["foreman_hook-host_rename"]

end
