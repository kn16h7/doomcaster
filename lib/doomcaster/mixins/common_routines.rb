module DoomCaster
  require 'colorize'
  
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
            print "==> ".bold
            answer = gets.chomp

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

    def shell
      print "==(#{$shell_pwd})> ".red.bold
    end

    def quit
      Arts::quit_banner
      Thread.exit
    end

    def ask(question, opts, &block)
      puts question.bold
      if block_given?
        array = AnswerArray.new(opts)
        yield array
        array.process_answer
      else
        print "==> ".bold
        gets.chomp
      end
    end

    def ask_no_question(question, &block)
      info "#{question}".red.bold
      print "==> ".red.bold
      gets.chomp
    end

    def die(msg)
      puts msg
      exit 1
    end
  end
end
