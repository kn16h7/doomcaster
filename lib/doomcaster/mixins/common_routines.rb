module DoomCaster
  require 'colorize'
  require 'readline'
  
  module Output
    class AnswerArray
      include Output
      
      def initialize(options)
        @options = options
        @option_handlers = {}
      end

      def on(opt, &block)
        @option_handlers[opt] = block
      end

      def process_answer
        loop do
          begin
            answer = Readline.readline( "==> ".bold, false)

            unless @options.include?(answer)
              fatal "Unknown option!"
              next
            else
              @option_handlers[answer].call
              break
            end
          rescue ArgumentError
            fatal "Invalid Input!"
          end
        end
      end
    end
   
    def info(msg)
      puts " [*] #{msg}".bold.red
    end

    def bad_info(msg)
      puts " [-] #{msg}".yellow.bold
    end

    def normal_info(msg)
      puts " [*] #{msg}".bold
    end

    def warn(msg)
      puts " [!] #{msg}".bold.yellow
    end

    def fatal(msg)
      puts " [-] #{msg}".bg_red
    end

    def good(msg)
      puts " [+] #{msg}".bold.green
    end

    def verbose(msg)
      puts " [v] #{msg}".blue if $verbose
    end

    def homossexual(msg)
      puts " [^] #{msg}".pink
    end

    def print_err_backtrace(e)
      if $trace
        puts "Error: #{e}"
        puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
      end
    end

    def fatalize_or_die(message)
      if $execution_mode == :once
        die message.bg_red
      else
        fatal message
        true
      end
    end

    def quit
      Arts::quit_banner
      Thread.exit
    end

    def ask(question, opts)
      puts question.bold
      if block_given?
        array = AnswerArray.new(opts)
        yield array
        array.process_answer
      else
        Readline.readline( "==> ".bold, false)
      end
    end

    def ask_no_question(question)
      info "#{question}".red.bold
      Readline.readline( "==> ".red.bold, false)
    end

    def read_num_from_user(question = nil)      
      puts question.red.bold if question
      loop do
        begin
          idx = Integer(Readline.readline( "==> ".red.bold, false))
          return idx
        rescue ArgumentError
          puts " Invalid input!".bg_red
        end
      end
    end

    def die(msg)
      puts msg
      exit 1
    end
  end
end
