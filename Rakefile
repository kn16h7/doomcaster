
$: << File.expand_path('lib')

require 'fileutils'
require 'jurandir'

task default: ['test', 'package']

task :test do
  ruby 'test/common_test.rb'
end

task :package do
  sh 'gem build jurandir.gemspec'
  FileUtils.mv("jurandir.rb-#{Jurandir::VERSION}.gem", File.expand_path('production'))
  FileUtils.cp('lists/', File.expand_path('production'))
end
