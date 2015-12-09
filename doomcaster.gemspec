Gem::Specification.new do |s|
  s.name = 'doomcaster'
  s.version = '1.9.8-BETA'
  s.summary = 'Protowave oficial Ruby script.'
  s.description = %q{Well, I think the origin of this script auto-explain its purpose, yeah?}
  s.authors = ['SuperSenpai']
  s.homepage = "http://www.protowave.org"
  s.license = 'GPL'

  files = []
  files << 'bin/doomcaster'
  `find -name "*.rb"`.split(/\n/).each { |file| files << file[2..-1] }
 
  s.files = files
  s.executables = s.files.grep(/^bin\//) { |file| File.basename(file) }
  s.require_paths = ['lib']
  s.add_runtime_dependency 'google-search', ['~> 1.0']
  s.add_runtime_dependency 'colorize', ['~> 0.7']
  s.add_runtime_dependency 'nokogiri', ['~> 1.6']
  s.add_runtime_dependency 'socksify', ['~> 1.6']
end
