module Jurandir
  module Modules
    require 'google-search'
    require 'net/http'
    
    class DorkScanner < Jurandir::JurandirModule
      def initialize
        super('dork-scanner', {})
        @vuln_sites = []
      end

      def desc
        Jurandir::ModuleDesc.new(
                                 %q{A tool to look for vulnerable sites based on a Google Dork},
                                 %Q{

                                 })
      end

      def get_domain
        print " [*] Digit the domain you want to scan (e.g. .com, .net, .org, etc): ".red.bold
        gets.chomp
      end

      def get_dork(list_path)
        puts " [*] Select the dork list you want to use, the available lists are:".red.bold
        lists = get_dork_lists(list_path)
        puts ""
        lists.each_index { |idx|
          puts " [#{idx}] #{lists[idx]}".red.bold
        }
        puts " [*] Custom dork".red.bold
        
        list = nil
        what_dork = nil
        custom = false
        
        loop do
          begin
            print " --> ".red.bold
            choice = gets.chomp

            if choice == '*'
              what_dork = custom_dork
              custom = true
              break
            end
            
            idx = Integer(choice)
            
            unless lists[idx]
              puts " Unknown list!".bg_red
            else
              list = lists[idx]
              break
            end
          rescue ArgumentError
            puts " Invalid input!".bg_red
          end
        end

        unless custom
          puts " [*] Ok! Loading wordlist.".red.bold
          in_memory_list = load_wordlist(list_path, list)

          loop do
            puts " [*] Selecting a random dork".red.bold

            size = in_memory_list.length
            what_dork = in_memory_list[Integer(rand(size))]
        
            puts " [*] Selected dork is #{what_dork}".green.bold

            print "Do you want to use this dork? [y/n] ".bold
            answer = gets.chomp

            if answer =~ /y/
              break
            elsif answer =~ /n/
              next
            else
              puts "Invalid answer! Jurandir will consider this as a no =)".bg_red
            end
          end
        end
        what_dork
      end

      def run
        @parser.parse!
        @vuln_sites = []
        
        list_path = unless self.options[:list_path]
                      ENV['HOME'] + "/.lolicon.rb/wordlists/dork-lists"
                    else
                      self.options[:list_path]
                    end
        
        puts " [*] Welcome to the Jurandir Dork Scanner!".green.bold
        
        domain = get_domain
        dork = get_dork(list_path)
        sanitized_dork = sanitize_dork(dork)
        complete_dork = domain + sanitized_dork

        puts " [*] The complete dork is: #{complete_dork}".green.bold
        amount = nil
        loop do
          begin
            puts "How many sites do you want to check for vulnerabilities?".bold
            print "--> ".bold
            amount = Integer(gets.chomp)
            break
          rescue ArgumentError
            puts "Invalid Input!".bg_red
          end
        end
        
        start_dork_scan(complete_dork, amount)
      end

      def load_sql_errors_list
        sql_list_file = ENV['HOME'] + '/.lolicon.rb/wordlists/sql-errors-list'
        retval = []
        file = File.open(sql_list_file)
        begin
          file.each_line do |line|
            retval << line
          end
        rescue
          file.close
        end
        retval
      end

      def check_sql_error(page_body)
        errors = load_sql_errors_list
        retval = false
        
        errors.each { |error|          
          retval = true if page_body =~ Regexp.new(error.chomp)
        }
        
        retval
      end

      def process_res(uri)
        puts " [*] Processing #{uri}...".red.bold
        puts " [*] Verifying if #{uri} responds".red.bold
        http_res = Net::HTTP.get_response(URI.parse(uri))

        if http_res.code =~ /200/
          puts " [+] #{uri} is ok!".green.bold
          puts " [*] Jurandir will check for vulnerability".red.bold

          obj_uri = URI.parse(uri)

          if obj_uri.query
            obj_uri.query = obj_uri.query + '\''
          else
            puts " [-] #{obj_uri} lacks of a parameter to check vulnerability".bold.yellow
            puts " [-] Jurandir will consider this seems not vulnerable".bold.yellow
            return false
          end
          
          http_res = Net::HTTP.get_response(obj_uri)

          if check_sql_error(http_res.body)
            puts " [+] #{uri} seems to be vulnerable!".green.bold
            @vuln_sites << uri
            return true
          else
            puts " [-] #{uri} seems not to be vulnerable.".yellow.bold
            return false
          end

        elsif http_res.code =~ /301/ || http_res.code =~ /302/
          redirection = if http_res['Location'] =~ /^http:/
                          http_res['Location']
                        else
                          uri + http_res['Location']
                        end

          puts "Got a redirection to: #{redirection}".bold
          loop do
            puts "Do you want to follow it? [y/n]: ".bold
            answer = gets.chomp

            if answer =~ /y/
              process_res(redirection)
              break
            elsif answer =~ /n/
              puts " [*] Ok.".bold.red
              break
            else
              puts "Invalid answer!".bg_red
            end
          end
        elsif http_res.code =~ /404/
          puts " [-] #{uri} is not ok: received a 404".bg_red
        else
          puts " [-] Jurandir received an unhandable HTTP status: #{http_res.code}".yellow.bold
        end
      end

      def start_dork_scan(dork, num = 1)
        puts " [*] Starting dork scanning...".green.bold
        query = "inurl:" + dork
        domain_cache = []
        
        #WARNING: DEBUG!
        count = 0
        Google::Search::Web.new(:query => query).each do |res|
          puts "\n"

          uri = URI.parse(res.uri)
          next if domain_cache.include?(uri.host)
          
          domain_cache << uri.host
          if process_res(res.uri)
            count += 1
          end
          
          break if count == num
        end

        puts " [*] Scanning complete, #{count} of sites that seem vulnerable were found, as you asked.".red.bold
        puts " [*] The sites are:".red.bold
        @vuln_sites.each { |site|
          puts " [+] #{site}".red.bold
        }
      end

      def sanitize_dork(dork)
        unless dork =~ /^\//
          dork = '/' + dork
        end
        dork
      end
        
      def custom_dork
        print " [*] Digit your custom dork: ".red.bold
        dork = gets.chomp
        dork
      end

      def load_wordlist(list_path, list)
        completed = false
        Thread.new  do
          until completed
            print '.'.bold
          end
        end

        retval = []
        
        Dir.foreach(list_path).select { |entry|
          !File.directory?(entry)
        }.each do |file|
          name = File.open(File.expand_path(file, list_path), "r").readline
          next if !(name =~ /NAME:/)
          name = File.open(File.expand_path(file, list_path), "r").readline
            .split(" ").drop(1).join(" ")

          if name == list
            File.open(list_path + '/' + file, 'r')
              .each_line { |line|
              next if line =~ /NAME:/
              retval << line
            }
            break
          end
        end

        completed = true
        puts '.'.bold
        retval
      end

      def parse_opts(parser)
        @parser = parser

        @parser.separator ""
        @parser.separator "dork-scanner options:"

        @parser.on("--list-path <path>", "The path where to look up for dork lists") do |path|
          self.options[:list_path] = path
        end

        @parser.on("--help", "This help message") do
          puts @parser
          exit
        end
      end

      def get_dork_lists(list_path)
        Dir.foreach(list_path).select { |entry|
          !File.directory?(entry)
        }.select {  |entry|
          !File.readable?(entry)
        }.select { |file|
          File.open(list_path + '/' + file, 'r').readline =~ /NAME:/
        }.collect { |file|
          File.open(list_path + '/' + file, 'r')
            .readline.split(" ").drop(1).join(" ")
        }
      end
    end
  end
end
