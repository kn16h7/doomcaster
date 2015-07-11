# -*- coding: utf-8 -*-

require 'colorize'

class String
  def bg_red
    self.colorize(:background => :red, :color => :white)
  end

  def orange
    "\e[38;5;208m#{self}\e[00m"
  end
end

module DoomCaster
  @@tools = {}

  class ToolDesc
    attr_reader :simple, :detailed
    
    def initialize(simple, detailed)
      @simple = simple
      @detailed = detailed
    end
  end
  
  class DoomCasterTool
    include DoomCaster::Output
    
    attr_reader :name
    attr_accessor :options
    protected :initialize

    def initialize(name, options = {})
      @name = name
      @options = options
    end

    def desc
      raise "Not implemented"
    end

    def print_manual
      raise "Not implemented"
    end

    def print_help
      raise "Not implemented"
    end

    def run
      raise "Not implemented"
    end

    def parse_opts(parser, args = ARGV)
      raise "Not implemented"
    end
  end

  def DoomCaster.register_tools
    @@tools['dc-admin-buster'] = Tools::AdminFinder.new
    @@tools['dcdorker'] = Tools::DorkScanner.new
  end

  def DoomCaster.get_tool(name, options = {})
    unless @@tools[name]
      raise UnknownToolError
    else
      @@tools[name].options = options
      @@tools[name]
    end
  end

  def DoomCaster.tools
    @@tools
  end
  
  def DoomCaster.banner
    system 'clear'
    Arts.main_banner
  end
  
  def DoomCaster.die(msg)
    puts msg
    exit 1
  end 
end
