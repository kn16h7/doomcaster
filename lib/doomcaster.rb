require 'doomcaster/errors'
require 'doomcaster/arts'
require 'doomcaster/mixins'
require 'doomcaster/common'
require 'doomcaster/tools'

module DoomCaster
  VERSION = '1.9.1'

  require 'optparse'
  require 'readline'

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
        user_input = Readline.readline("==(#{$shell_pwd})> ".red.bold, true)
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

            puts "\nTools:".red.bold
            DoomCaster::tools.keys.each { |key|
              puts "#{key}\t#{DoomCaster::tools[key].desc.simple}".red.bold
            }
          end
        else
          begin
            parser = OptionParser.new
            what_tool = DoomCaster::get_tool(command)

            begin
              what_tool.parse_opts(parser, args)
            rescue StandardError => e
              fatal "Error on command line parsing #{e}"
              next
            end

            if pure_args.include?('--help') || pure_args.include?('--manual')
              next
            else
              what_tool.run_tool
              $shell_pwd = 'toolkit'
            end
          rescue UnknownToolError
            fatal "Unknown command or tool: #{command}"
          rescue OptionParser::InvalidOption => e
            fatal "#{e.message} for tool: #{what_tool.name}"
          rescue ToolExecFailedError => e
            fatal "Execution of tool #{what_tool.name} failed"
          end
        end
      end
    end
  end
  
  class Application
    extend Output

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
                         'quit' => lambda {
                           quit
                         }
                        }
    
    def Application.setup
      trap('INT') do
        puts "Exiting (user interrupt)".red.bold
        exit
      end

      unless ENV['DOOMCASTER_HOME']
        ENV['DOOMCASTER_HOME'] = ENV['HOME'] + '/.doomcaster'
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
            fatalize_or_die "ERROR: Unknown tool: #{options[:tool]}"
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

        opts.on("--verbose", "Turn on verboseness") do |opt|
          $verbose = true
        end

        opts.on('--doomcaster-home <home>', 'The home directory where doomcaster will look for everything') do |opt|
          unless File.exists?(opt)
            fatal "Specified DoomCaster home does not exist!"
            exit 1
          else
            ENV['DOOMCASTER_HOME'] = opt
          end
        end

        opts.on("--debug", "Turn on debug mode") do
          $debug = true
        end

        opts.on("--version", "Print the version and exit") do
          puts "DoomCaster Version #{VERSION}"
          exit
        end
      end

      begin
        main_parser.parse!
      rescue StandardError => e
        fatal "Error on command line parsing: #{e}"
        exit 1
      end

      verbose "DoomCaster launched at #{Time.new.inspect}"
      verbose "DoomCaster home: #{ENV['DOOMCASTER_HOME']}"
      verbose "DoomCaster current user: #{ENV['USER']}"
      verbose "DoomCaster version: #{VERSION}"
      
      begin
        unless what_tool
          interactive_run
        else
          what_tool.run_tool
        end
      rescue ToolExecFailedError => e
        fatal "Execution of tool #{e.message} failed"
      end
    end

    def Application.interactive_run
      $shell_pwd = 'main_menu'
      DoomCaster::banner
      $ended = false
      info "Welcome to DoomCaster! To get a list of commands, digit help."
      
      until $ended
        command = Readline.readline("==(#{$shell_pwd})> ".red.bold, true)
        if COMMANDS_ROUTINES.keys.include?(command)
          COMMANDS_ROUTINES[command].call
        else
          fatal "Unknown command: #{command}"
        end
      end
    end
  end
end
