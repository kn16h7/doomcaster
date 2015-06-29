#!/usr/bin/ruby

require 'optparse'
require 'colorize'

module Jurandir
  require 'jurandir'

  def Jurandir.main(parser, opts = {})
    Jurandir::banner

    begin
      tool = Jurandir.create(options[:tool], options[:tool_opts])
      tool.parse_opts(parser)
    rescue UnknownModuleError
      Jurandir::die "ERROR: Unknown tool #{options[:tool]}".bg_red
    end
    tool.run
  end  
end

options = {
  :tool => nil,
  :tool_opts => {}
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby jurandir.rb [options]"

  opts.on("--tool <tool>", "What tool will be used") do |tool|
    options[:tool] = tool
  end
  
  opts.on("--help", "Print this help message") do |opt|
    puts opts
    exit
  end
end

Jurandir::main(parser, options)
