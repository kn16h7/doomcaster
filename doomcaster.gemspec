Gem::Specification.new do |s|
  s.name = 'doomcaster'
  s.version = '1.8.7'
  s.summary = 'Lolicon Squad oficial Ruby script.'
  s.description = %q{Well, I think the origin of this script auto-explain its purpose, yeah?}
  s.authors = ['SuperSenpai', 'PrestusHood']
  s.homepage = "http://www.protowave.org"
  s.license = 'GPL'
  
  files = `git ls-files`.split(/\n/)

  ['.gitignore', 'Rakefile', 'doomcaster.gemspec', 'CHANGELOG'].each { |file|
    files.delete(file)
  }
 
  files.grep(/(^wordlists|^production)/).each { |file| files.delete(file) }
 
  s.files = files
  s.executables = s.files.grep(/^bin\//) { |file| File.basename(file) }
  s.test_files = s.files.grep(/^test\//)
  s.require_paths = ['lib']
  s.add_runtime_dependency 'google-search', ['>= 1.0.3']
  s.add_runtime_dependency 'colorize', ['>= 0.7.7']
end
