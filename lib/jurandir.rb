$: << File.expand_path(File.dirname(__FILE__))

require 'jurandir/common'
require 'jurandir/admin-finder'
require 'jurandir/errors'

module Jurandir
  VERSION = '1.5'

  require 'optparse'
  
  class Application

    def Application.setup
      trap('INT') do
        puts "Exiting (user interrupt).."
        exit
      end
    end
    
    def Application.run
      Jurandir::register_modules
      setup

      options = {
                 :tool => nil,
                 :tool_opts => {}
                }

      what_tool = nil
      
      main_parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby jurandir.rb [options]"
        
        opts.on("--tool <tool>", "What tool will be used") do |tool|
          options[:tool] = tool

          begin
            what_tool = Jurandir::get_module(options[:tool], options[:tool_opts])
            what_tool.parse_opts(main_parser)
          rescue UnknownModuleError
            unless options[:tool]
              Jurandir::die "ERROR: No tool specified!".bg_red
            else
              Jurandir::die "ERROR: Unknown tool: #{options[:tool]}".bg_red
            end
          end
        end
        
        opts.on("--tools", "Show available tools") do
          Jurandir::modules.keys.each { |key|
            puts key
          }
          exit
        end
          
        opts.on("--help", "Print this help message") do |opt|
          puts opts
          exit
        end
      end

      main_parser.parse!

      unless what_tool
        Jurandir::die "ERROR: No tool given!".bg_red
      end
      
      Jurandir::banner      
      what_tool.run
    end
  end
end
