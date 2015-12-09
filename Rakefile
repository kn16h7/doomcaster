VERSION = '1.9.8.pre.BETA'

task default: ['package']

desc "Build the project in a distributable zip."
task :package do
  sh 'gem build doomcaster.gemspec'
  mv("doomcaster-#{VERSION}.gem", 'production')
  copy('Rakefile', 'production')
  copy_entry('wordlists/', 'production/wordlists')
  sh "zip -r doomcaster-#{VERSION}.zip production/"
end

desc "Delete all production files."
task :clean do
  if File.basename(Dir.pwd) == 'production'
    Dir.chdir('..')
  end
  
  File.delete("doomcaster-#{VERSION}.zip")
  Dir.chdir('production')
  File.delete("doomcaster-#{VERSION}.gem")
  File.delete("Rakefile")
  rm_r('wordlists')
end

desc "Do everything and install"
task :all => :default  do
  Dir.chdir('production')
  sh 'sh install.sh'
end
