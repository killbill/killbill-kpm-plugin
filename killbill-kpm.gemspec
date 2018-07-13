version = File.read(File.expand_path('../VERSION', __FILE__)).strip

Gem::Specification.new do |s|
  s.name        = 'killbill-kpm'
  s.version     = version
  s.summary     = 'Kill Bill KPM plugin'
  s.description = 'Plugin to manage installed plugins'

  s.required_ruby_version = '>= 1.9.3'

  s.license = 'Apache License (2.0)'

  s.author   = 'Killbill core team'
  s.email    = 'killbilling-users@googlegroups.com'
  s.homepage = 'http://killbill.io'

  s.files         = Dir['lib/**/*']
  s.bindir        = 'bin'
  s.require_paths = ['lib']

  s.rdoc_options << '--exclude' << '.'

  s.add_dependency 'killbill', '~> 9.4'
  s.add_dependency 'kpm', '~> 0.6.0'
  s.add_dependency 'activesupport', '~> 4.2', '>= 4.2.10'

  s.add_development_dependency 'jbundler', '~> 0.9.2'
  s.add_development_dependency 'rake', '>= 10.0.0', '< 11.0.0'
  s.add_development_dependency 'rspec', '~> 3.5.0'
end
