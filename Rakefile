$: << File.expand_path('lib')

require 'fileutils'
require 'jurandir'

task default: ['test', 'package']

desc "Perform tests."
task :test do
  ruby 'test/common_test.rb'
end

desc "Build the project in a distributable zip."
task :package do
  sh 'gem build jurandir.gemspec'
  FileUtils.mv("jurandir.rb-#{Jurandir::VERSION}.gem", 'production')
  FileUtils.copy_entry('lists/', 'production/lists')
  sh "zip -r jurandir-#{Jurandir::VERSION}.zip production/"
end

desc "Delete all production files."
task :clean do
  File.delete("jurandir-#{Jurandir::VERSION}.zip")
  Dir.chdir('production')
  File.delete("jurandir.rb-#{Jurandir::VERSION}.gem")
  FileUtils.rm_r('lists')
end
