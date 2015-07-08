require 'doomcaster/errors'
require 'doomcaster/common'
require 'doomcaster/mixins'
require 'doomcaster/tools'

module DoomCaster
  VERSION = '1.8.7'

  require 'optparse'
  
  class Application
    def Application.setup
      trap('INT') do
        puts "Exiting (user interrupt)..".red.bold
        exit
      end
    end
    
    def Application.run
      DoomCaster::register_tools
      setup

      options = {
                 :tool => nil,
                 :tool_opts => {}
                }

      what_tool = nil
      
      main_parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby doomcaster [options]"
        
        opts.on("--tool <tool>", "What tool will be used") do |tool|
          options[:tool] = tool

          begin
            what_tool = DoomCaster::get_tool(options[:tool], options[:tool_opts])
            what_tool.parse_opts(main_parser)
          rescue UnknownToolError
            unless options[:tool]
              DoomCaster::die "ERROR: No tool specified!".bg_red
            else
              DoomCaster::die "ERROR: Unknown tool: #{options[:tool]}".bg_red
            end
          end
        end
        
        opts.on("--tools", "Show available tools") do
          DoomCaster::tools.keys.each { |key|
            puts "#{key}\t#{DoomCaster::modules[key].desc.simple}"
          }
          exit
        end
          
        opts.on("--help", "Print this help message") do |opt|
          puts opts
          exit
        end

        opts.on("--version", "Print the version and exit") do
          puts "DoomCaster Version #{VERSION}..."
          exit
        end
      end

      main_parser.parse!

      unless what_tool
        DoomCaster::die "ERROR: No tool given!".bg_red
      end
      
      DoomCaster::banner      
      what_tool.run
    end
  end
end
