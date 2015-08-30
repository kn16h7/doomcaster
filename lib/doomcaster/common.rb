# -*- coding: utf-8 -*-

require 'colorize'

class String
  def bg_red
    self.colorize(:background => :red, :color => :white)
  end

  def blue
    "\e[1;34m#{self}\e[0m"
  end

  def pink
    "\e[1;35m#{self}\e[0m"
  end

  def orange
    "\e[38;5;208m#{self}\e[0m"
  end

  def String.remove_quotes_if_has_quotes(str)
    if (str.start_with?('\'') && str.end_with?('\'')) ||
        (str.start_with?('"') && str.end_with?('"'))
      str = str[1..str.length - 2]
    end
    str
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
    extend DoomCaster::Output
    
    attr_reader :name
    attr_accessor :options
    protected :initialize

    def initialize(name, options = {})
      @name = name
      @options = options
    end

    def desc
      raise NotImplementedError
    end
    
    def run
      raise NotImplementedError
    end

    def parse_opts(parser, args = ARGV)
      raise NotImplementedError
    end
  end

  def DoomCaster.register_tools
    @@tools['dc-admin-buster'] = Tools::AdminFinder.new
    @@tools['dcdorker'] = Tools::DorkScanner.new
    @@tools['dc-sqlmap-wrapper'] = Tools::SqlmapWrapper.new
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
end
