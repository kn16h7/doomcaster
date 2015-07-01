
Gem::Specification.new do |s|
  s.name = 'lolicon.rb'
  s.version = '1.5'
  s.summary = 'Lolicon Squad oficial Ruby script.'
  s.description = %q{Well, I think the origin of this script auto-explain its purpose, yeah?}
  s.authors = ['SuperSenpai', 'PrestusHood']
  s.homepage = "http://www.protowave.org"
  
  files = `git ls-files`.split($/)
  files.delete('.gitignore')
  files.delete('Rakefile')
  files.delete('jurandir.gemspec')
  
  s.files = files
  s.executables = s.files.grep(/^bin\//) { |file| File.basename(file) }
  s.test_files = s.files.grep(/^test\//)
  s.require_paths = ['lib']
end
