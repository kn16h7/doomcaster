#!/usr/bin/ruby

require 'optparse'
require 'colorize'

$:.unshift(File.expand_path('../lib'))

module Jurandir
  require 'jurandir'

  def Jurandir.main(options = {})
    Jurandir::register_modules
    
    begin
      tool = Jurandir::create_module(options[:tool], options[:tool_opts])
      tool.parse_opts(OptionParser.new)
    rescue UnknownModuleError
      Jurandir::die "ERROR: Unknown tool: #{options[:tool]}".bg_red
    end
    
    Jurandir::banner   
    tool.run
  end
end

options = {
  :tool => nil,
  :tool_opts => {}
}

OptionParser.new do |opts|
  opts.banner = "Usage: ruby jurandir.rb [options]"

  opts.on("--tool <tool>", "What tool will be used") do |tool|
    options[:tool] = tool
  end
  
  opts.on("--help", "Print this help message") do |opt|
    puts opts
    exit
  end
end.parse!

Jurandir::main(options)
