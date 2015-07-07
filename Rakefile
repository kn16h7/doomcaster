VERSION = '1.8.5'

task default: ['test', 'package']

desc "Perform tests."
task :test do
  ruby 'test/common_test.rb'
end

desc "Build the project in a distributable zip."
task :package do
  sh 'gem build doomcaster.gemspec'
  mv("doomcaster-#{VERSION}.gem", 'production')
  copy_entry('wordlists/', 'production/wordlists')
  sh "zip -r doomcaster-#{VERSION}.zip production/"
end

desc "Delete all production files."
task :clean do
  File.delete("doomcaster-#{VERSION}.zip")
  Dir.chdir('production')
  File.delete("doomcaster-#{VERSION}.gem")
  rm_r('wordlists')
end

desc "Do everything and install"
task :all => :default  do
  Dir.chdir('production')
  puts Dir.getwd
  sh 'sh install.sh'
end
