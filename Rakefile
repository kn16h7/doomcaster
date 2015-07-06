$: << File.expand_path('lib')

require 'doomcaster'

task default: ['test', 'package']

desc "Perform tests."
task :test do
  ruby 'test/common_test.rb'
end

desc "Build the project in a distributable zip."
task :package do
  sh 'gem build doomcaster.gemspec'
  mv("doomcaster-#{DoomCaster::VERSION}.gem", 'production')
  copy_entry('wordlists/', 'production/wordlists')
  sh "zip -r doomcaster-#{DoomCaster::VERSION}.zip production/"
end

desc "Delete all production files."
task :clean do
  File.delete("doomcaster-#{DoomCaster::VERSION}.zip")
  Dir.chdir('production')
  File.delete("doomcaster-#{DoomCaster::VERSION}.gem")
  rm_r('wordlists')
end
