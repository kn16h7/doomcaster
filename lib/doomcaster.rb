require 'doomcaster/errors'
require 'doomcaster/arts'
require 'doomcaster/mixins'
require 'doomcaster/common'
require 'doomcaster/tools'

module DoomCaster
  VERSION = '1.8.9'

  require 'optparse'

  class ToolKitSession < Thread
    include Output
    
    COMMANDS = ['back', 'quit', 'help']
    HELP = {
            'back' => 'Back to main menu',
            'quit' => 'Quit script',
            'help' => 'This help message'
           }
    
    def initialize
      super {
             Thread.stop
            }
    end
    
    def run
      Arts::toolkit
      $shell_pwd = 'toolkit'
      ended = false
      
      until ended
        shell
        user_input = gets.chomp
        parts = user_input.split(" ")
        command = parts[0]
        args = parts.drop(1)
        pure_args = args.clone
        
        if COMMANDS.include?(command)
          case command
          when 'back'
            ended = true
          when 'quit'
            quit
          when 'help'
            HELP.each { |key, value|
              puts "#{key}\t#{value}".red.bold
            }

            puts ""
            puts "Tools:".red.bold
            DoomCaster::tools.keys.each { |key|
              puts "#{key}\t#{DoomCaster::tools[key].desc.simple}".red.bold
            }
          end
        else
          begin
            parser = OptionParser.new
            what_tool = DoomCaster::get_tool(command)
            what_tool.parse_opts(parser, args)

            if pure_args.include?('--help') || pure_args.include?('--manual')
              next
            else
              what_tool.run
              $shell_pwd = 'toolkit'
            end
          rescue UnknownToolError
            fatal "Unknown command or tool: #{command}."
          end
        end
      end
    end

    
  end
  
  class Application
    extend Output

    COMMANDS = ['arsenal', 'toolkit', 'help', 'procedures', 'contact', 'quit']
    COMMANDS_ROUTINES = {
                         'arsenal' => lambda {
                           Arts::arsenal
                         },
                         'toolkit' => lambda {
                           system('clear')
                           t = ToolKitSession.new
                           t.run
                           Application.interactive_run
                         },
                         'help' => lambda {
                           Arts.help
                         },
                         'procedures' => lambda {
                           fatal "Not implemented yet!"
                         },
                         'contact' => lambda {
                           
                         },
                         'quit' => lambda {
                           quit
                         }
                        }
    
    def Application.setup
      trap('INT') do
        puts "Exiting (user interrupt)".red.bold
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

          if options[:tool]
            $execution_mode = :once
          else
            $execution_mode = :interactive
          end

          begin
            what_tool = DoomCaster::get_tool(options[:tool], options[:tool_opts])
            what_tool.parse_opts(main_parser)
          rescue UnknownToolError
            DoomCaster::die "ERROR: Unknown tool: #{options[:tool]}".bg_red
          end
        end
        
        opts.on("--arsenal", "Show available tools") do
          DoomCaster::tools.keys.each { |key|
            puts "#{key}\t#{DoomCaster::tools[key].desc.simple}"
          }
          exit
        end
          
        opts.on("--help", "Print this help message") do |opt|
          puts opts
          exit
        end

        opts.on("--version", "Print the version and exit") do
          puts "DoomCaster Version #{VERSION}"
          exit
        end
      end

      main_parser.parse!

      unless what_tool
        interactive_run
      else
        what_tool.run
      end
    end

    def Application.interactive_run
      $shell_pwd = 'main_menu'
      DoomCaster::banner
      $ended = false
      info "Welcome to DoomCaster! To get a list of commands, digit help."
      
      until $ended
        shell
        command = gets.chomp
        if COMMANDS.include?(command)
          COMMANDS_ROUTINES[command].call
        else
          fatal "Unknown command: #{command}"
        end
      end
    end
  end
end
