#require File.expand_path("../lib/newgem/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "foreman_hook-host_rename"
  s.version     = '0.0.1'
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Mark Heily", "Bronto Software, Inc."]
  s.email       = ["mark.heily@bronto.com"]
  s.homepage    = "https://github.com/bronto/foreman_hook-host_rename"
  s.summary     = "Foreman hook that fires when a host is renamed"
  s.description = "See the README for details"

  # Dependencies
  %w(json sqlite3 rest_client kwalify).each { |dep| s.add_dependency dep }

  # If you need to check in files that aren't .rb files, add them here
  s.files        = Dir[
	"conf/{schema.yaml,settings.yaml.EXAMPLE}",
	"bin/*", "LICENSE", "*.md", "Gemfile",
	]
  #s.require_path = 'lib'

  # If you need an executable, add it here
  # s.executables = ["newgem"]

end
