module DoomCaster
  require 'colorize'
  
  module Output
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

    def ask(question, &block)
      puts question.bold
      print "==> ".bold
      answer = gets.chomp
      if block_given?
        yield answer
      else
        answer
      end
    end

    def ask_no_question(question, &block)
      ask(" [*] #{question}".red, &block)
    end

    def die(msg)
      puts msg
      exit 1
    end
  end
end
