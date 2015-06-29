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

module Jurandir
  require 'net/http'
  require 'colorize'

  @@modules = {}
  
  class JurandirModule
    attr_reader :name, :options
    protected :initialize

    def initialize(name, options = {})
      @name = name
      @options = options
    end

    def run
      raise "Not implemented"
    end

    def parse_opts(parser)
      raise "Not implemented"
    end
  end

  def Jurandir.register_modules
    @@modules['admin-finder'] = Modules::AdminFinder
  end

  def Jurandir.create_module(name, opts)
    unless @@modules[name]
      raise UnknownModuleError
    else
      @@modules[name].new(opts)
    end
  end
  
  def Jurandir.banner
    system 'cls'
    print "\n".red.bold
    print "   ___                           _ _         ___      _           _        ______ _           _           \n".red.bold
    print "  |_  |                         | (_)       / _ \\    | |         (_)       |  ___(_)         | |          \n".red.bold
    print "    | |_   _ _ __ __ _ _ __   __| |_ _ __  / /_\\ \\ __| |_ __ ___  _ _ __   | |_   _ _ __   __| | ___ _ __ \n".red.bold
    print "    | | | | | '__/ _` | '_ \\ / _` | | '__| |  _  |/ _` | '_ ` _ \\| | '_ \\  |  _| | | '_ \\ / _` |/ _ \\ '__|\n".red.bold
    print "/\\__/ / |_| | | | (_| | | | | (_| | | |    | | | | (_| | | | | | | | | | | | |   | | | | | (_| |  __/ |   \n".red.bold
    print "\\____/ \\__,_|_|  \\__,_|_| |_|\\__,_|_|_|    \\_| |_/\\__,_|_| |_| |_|_|_| |_| \\_|   |_|_| |_|\\__,_|\\___|_|   \n".red.bold
    print "                   .:/+ooo++/-.                   \n".red.bold
    print "              -+ooo/-.`   ``.:+ooo/.              +------------------------------------------------------+\n".red.bold
    print "           -ss/`                  -oso.           | .:jurandir.rb, the perfect admin panel finder v1.5:. |\n".red.bold
    print "         /h+`                      -oyMh-         |        .:Coded By SuperSenpai & PrestusHood:.        |\n".red.bold
    print "       :domd/`                   .-.yNMssy.       |~+~Sponsored by Lolicon Squad & ProtoWave Reloaded~+~ |\n".red.bold
    print "      sMd  +NN+                    `MNNN .d/      |                                                      |\n".red.bold
    print "    `hsMh   /M+                    -s/MN  `h+     |                     <:~Contact:~>                    |\n".red.bold
    print "    h+ oN`   ++`                   `oNN+    d/    |                                                      |\n".red.bold
    print "   +h   /h-          `           -.yMo`     .N`   | ___ ___     -------------------+---------------------|\n".red.bold
    print "   N:     --.`    `hMMy         sMMNM-       yo   || __| _ ) <> fb.com/protowave02 | fb.com/loliconsquad |\n".red.bold
    print "  -M          :   -MMNs`        :yMhM-   `.``/d   || _|| _ \\                       |                     |\n".red.bold
    print "  :m          d    -/.            ` M`.:-.   :m   ||_| |___/ <> fb.com/supersenpai | fb.com/prestushood1 |\n".red.bold
    print "  -M          M/                   `d:.      /h   |             -------------------+---------------------|\n".red.bold
    print "   m:         mN/                `.+:...--::-d+   |                                                      |\n".red.bold
    print "   +d.-----:--:hMh..````           :        .m`   |                                                      |\n".red.bold
    print "    ho     .---.:yd/.`            -/-:/+:---m:    |                                                      |\n".red.bold
    print "    `ho-:::.---....//:-   `oyNdh`:h.-` `-::d/     |                                                      |\n".red.bold
    print "      sy`:::`.----.. -/s:` .hNmyhh--`-::`-d:      |                                                      |\n".red.bold
    print "       :d+.::../-  ::  `/hmNMdys/   :: .hs`       |                                                      |\n".red.bold
    print "         /ho./-   /.                 -hs.         |                                                      |\n".red.bold
    print "           -sy+. -               `:os+`           |                                                      |\n".red.bold
    print "              .+sso+:-..``..-/oooo:`              |        〜(^∇^〜）Sejam vadias mágicas（〜^∇^)〜        |\n".red.bold
    print "                   `-:/+++//:.`                   +------------------------------------------------------+\n".red.bold
    print "\n"
  end
  
  def Jurandir.die(msg)
    puts msg
    exit 1
  end 
end
