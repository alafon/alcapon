Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'alcapon'
  s.version     = '0.4.11'
  s.add_dependency 'capistrano', '>= 2.12.0'
  s.add_dependency 'colored', '>= 1.2'
  s.date        = '2013-04-02'
  s.summary     = "Enable Capistrano for your eZ Publish projects"
  s.description = "Capistrano is a utility and framework for executing commands in parallel on multiple remote machines, via SSH. This package gives you some tools to deploy your eZ Publish projects."
  s.authors     = ["Arnaud Lafon"]
  s.email       = 'alcapon@arnaudlafon.com'
  s.homepage    = 'http://alafon.github.com/alcapon'

  s.files = Dir.glob("{bin,lib}/**/*") + %w(README.md LICENSE.md)

  s.require_path = 'lib'
  s.has_rdoc = false

  s.bindir = "bin"
  s.executables << "capezit"
end
