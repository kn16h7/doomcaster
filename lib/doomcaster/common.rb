# -*- coding: utf-8 -*-

require 'colorize'

class Array
  def contains_all? other
    other = other.dup
    each{|e| if i = other.index(e) then other.delete_at(i) end}
    other.empty?
  end
end

class String
  def bg_red
    self.colorize(:background => :red, :color => :white)
  end
end

module DoomCaster
  require 'net/http'

  @@modules = {}

  class ToolDesc
    attr_reader :simple, :detailed
    
    def initialize(simple, detailed)
      @simple = simple
      @detailed = detailed
    end
  end

  
  class DoomCasterTool
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

    def run
      raise "Not implemented"
    end

    def parse_opts(parser)
      raise "Not implemented"
    end
  end

  def DoomCaster.register_modules
    @@modules['admin-finder'] = Tools::AdminFinder.new
    @@modules['dork-scanner'] = Tools::DorkScanner.new
  end

  def DoomCaster.get_module(name, options = {})
    unless @@modules[name]
      raise UnknownToolError
    else
      @@modules[name].options = options
      @@modules[name]
    end
  end

  def DoomCaster.modules
    @@modules
  end
  
  def DoomCaster.banner
    system 'clear'
    print "\n"
    print " _           _ _                   _____           _ _    _ _                   \n".bold.red
    print "| |         | (_)                 |_   _|         | | |  (_) |  　     ∩＿＿＿∩  \n".bold.red
    print "| |     ___ | |_  ___ ___  _ __     | | ___   ___ | | | ___| |_      |ノ  　  ヽ \n".bold.red
    print "| |    / _ \\| | |/ __/ _ \\| '_ \\    | |/ _ \\ / _ \\| | |/ / | __|    /　 ●　  ●  |\n".bold.red
    print "| |___| (_) | | | (_| (_) | | | |   | | (_) | (_) | |   <| | |_    |　 ( _●_)  ミ\n".bold.red
    print "\\_____/\\___/|_|_|\\___\\___/|_| |_|   \\_/\\___/ \\___/|_|_|\\_\\_|\\__|  彡､  　 |∪| ､｀＼\n".bold.red
    print "+------------------------------------------------------------------------------+\n".bold.red
    print "|               .:lolicon.rb the perfect tookit for lazy hacking:.             |\n".bold.red
    print "|                     .:Coded By SuperSenpai & PrestusHood:.                   |\n".bold.red
    print "|             ~+~Sponsored by Lolicon Squad & ProtoWave Reloaded~+~            |\n".bold.red
    print "|                                                                              |\n".bold.red
    print "|                                 <:~Contact:~>                                |\n".bold.red
    print "|                                                                              |\n".bold.red
    print "||FB:/protowave02 |FB:/loliconsquad |FB:/PrestusHood1   |FB:id=100003199327670 |\n".bold.red
    print "||TT:@Protowave01 |TT: N/A          |TT:@PrestusHood    |TT: N/A               |\n".bold.red
    print "||YT: N/A         |YT: N/A          |YT:/PrestusHood    |YT: N/A               |\n".bold.red
    print "||Steam: N/A      |Steam: N/A       |Steam:/PrestusHood |Steam:/SuperSenpai    |\n".bold.red
    print "|                                                                              |\n".bold.red
    print "|            Support us buying steam games and sejam vadias mágicas            |\n".bold.red
    print "+------------------------------------------------------------------------------+\n".bold.red
  end
  
  def DoomCaster.die(msg)
    puts msg
    exit 1
  end 
end
