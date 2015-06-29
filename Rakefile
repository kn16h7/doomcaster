require 'fileutils'

task default: ['test']

task :test do
  ruby 'test/common_test.rb'
end

task :package do
  sh 'gem build jurandir.gemspec'
  FileUtils.mv()
end
