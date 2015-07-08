module DoomCaster
  module Tools
    require 'google-search'
    require 'timeout'
    require 'net/http'
    
    class DorkScanner < DoomCaster::DoomCasterTool
      include DoomCaster::HttpUtils
      
      def initialize
        super('dcdorker', {})
        @vuln_sites = []
      end
      
      public
      def desc
        DoomCaster::ToolDesc.new(
                                 %q{A tool to look for vulnerable sites based on a Google Dork},
                                 %Q{
This tool takes: A random dork from a wordlist or a custom dork provided by
the user and a domain. Then, it uses it to look for sites vulnerable to SQL
Injection on Google. The user says how many sites he/she wants and this tool
will look for as many sites as possible and deliver them to the user.

LISTS:
You can create you own list of dorks, to this, go to the directory:
/home/<your-home>/.doomcaster/wordlists/dork-lists and create a new file with
the first line as:
NAME: <name of your dork list>

Then just put the dorks, one per line.

Doomcaster comes with a default dork lists called Super Word List, with a total
of 28605 dorks.
                                 })
      end

      def run
        @parser.parse!
        @vuln_sites = []
        
        list_path = unless self.options[:list_path]
                      ENV['HOME'] + "/.doomcaster/wordlists/dork-lists"
                    else
                      self.options[:list_path]
                    end
        
        puts " [*] Welcome to the DoomCaster Dork Scanner!".red.bold
        
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

      def parse_opts(parser)
        @parser = parser
        
        @parser.separator ""
        @parser.separator "dork-scanner options:"
        
        @parser.on("--list-path <path>", "The path where to look up for dork lists") do |path|
          self.options[:list_path] = path
        end
        
        @parser.on('--manual', 'Display a detailed explanation of this tool') do
          puts self.desc.detailed
          exit
        end
        
        @parser.on("--help", "This help message") do
          puts @parser
          exit
        end
      end

      private
      def get_domain
        puts " [*] Digit the domain you want to scan (e.g. .com, .net, .org, etc). ".red.bold
        puts " [*] If you don't care about the domain, just hit return.".red.bold
        print "-->".red.bold
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
              puts "Invalid answer! DoomCaster will consider this as a no =)".bg_red
            end
          end
        end
        what_dork
      end
      
      def load_sql_errors_list
        sql_list_file = ENV['HOME'] + '/.doomcaster/wordlists/sql-errors-list'
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
      
      def get_parameters(query)
        query.split("&")
      end

      def vuln_parameter(query, param)
        chunks = query.split("&")
        chunks.each_index { |idx|
          if param == chunks[idx]
            chunks[idx] << "'"
            break
          end
        }
        chunks.join("&")
      end

      def process_res(uri)
        puts " [*] Processing #{uri}...".red.bold
        puts " [*] Verifying if #{uri} is alright...".red.bold

        unless uri.query
          puts " [-] #{uri} lacks of a parameter to check vulnerability".bold.yellow
          puts " [-] DoomCaster will consider this site seems not vulnerable".bold.yellow
          return false
        end
        
        http_res = nil
        begin
          Timeout::timeout(60) do
            http_res = do_http_get(uri, 10)
          end
        rescue Errno::ETIMEDOUT
          puts " [-] Connection to #{uri} timed out, going to the next".bg_red
          return false
        rescue Errno::ECONNREFUSED
          puts " [-] #{uri} refused our connection".bg_red
          return false
        rescue Net::HTTPBadResponse => e
          puts " [-] Server gave to us an bad response: #{e}, going to the next".bold.yellow
          return false
        rescue SocketError => e
          puts " [-] Network error while trying to test (#{e}), going to the next".bg_red
          return false
        rescue Timeout::Error
          puts " [-] Site took a very long time to download, giving up of this site and going to the next".bg_red
          return false
        end

        if http_res.code =~ /200/
          puts " [+] #{uri} is ok!".green.bold
          puts " [*] DoomCaster will check for vulnerability".red.bold

          vuln_uri = uri.clone

          params = get_parameters(uri.query)

          if params.length > 1
            puts " [+] This URI has more than one parameter! Doomcaster will check for vulnerabilities in each one.".green.bold
          end

          vuln_detected = false
          params.each do |param|
            vuln_uri.query = vuln_parameter(uri.query, param)

            begin
              Timeout::timeout(60) do
                http_res = do_http_get(vuln_uri)
              end
            rescue Timeout::Error
              puts " [-] Site took a very long time to download, giving up of this site and going to the next".bg_red
              return false
            rescue Net::NetReadTimeout
              puts " [-] Connection timed out, going to the next".bg_red
              return false
            end

            if check_sql_error(http_res.body)
              puts " [+] The parameter #{param} of #{uri} seems vulnerable!".green.bold
              @vuln_sites << uri
              vuln_detected = true
            else
              puts " [-] Parameter #{param} of #{uri} seems not vulnerable.".yellow.bold
            end
          end
          return vuln_detected
        elsif http_res.code =~ /301/ || http_res.code =~ /302/
          redirection = if http_res['Location'] =~ /^http:/
                          http_res['Location']
                        else
                          uri + http_res['Location']
                        end

          puts "Got a redirection to: #{redirection}".bold
          loop do
            print "Do you want to follow it? [y/n]: ".bold
            answer = gets.chomp

            if answer =~ /y/
              encoded_redirection = URI.escape(redirection.to_s)
              process_res(URI.parse(encoded_redirection))
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
          puts " [-] DoomCaster received an unhandable HTTP status: #{http_res.code}".yellow.bold
        end
      end

      def start_dork_scan(dork, num = 1)
        puts " [*] Starting dork scanning...".green.bold
        query = "inurl:" + dork
        domain_cache = []
        
        #WARNING: DEBUG!
        count = 0
        begin
          Google::Search::Web.new(:query => query).each do |res|
            uri = URI.parse(res.uri)
            next if domain_cache.include?(uri.host)
            
            puts "\n"
            
            domain_cache << uri.host
            encoded_uri = URI.encode(res.uri)
            if process_res(URI.parse(encoded_uri))
              count += 1
            end
            
            break if count == num
          end
        rescue IOError
          DoomCaster::die " [FATAL] I/O Error while scanning.".bg_red
        end

        if count != num
          puts " [-] It seems that this dork didn't give us sufficient results." +
            " It may be because this dork is unefficient and Google cannot provide " +
            "a good number of sites to test. I recommend you to try other dorks.".bold.yellow
          return
        end
        
        puts "\n [*] Scanning complete, #{count} of sites that seem vulnerable were found," +
          "as you asked.".green.bold
        puts " [*] The sites are:".green.bold
        @vuln_sites.each { |site|
          puts " [+] #{site}".green.bold
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
            sleep 1
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
            File.open(list_path + '/' + file, 'r').each_line do |line|
              next if line =~ /NAME:/
              retval << line
            end
            break
          end
        end

        completed = true
        puts '.'.bold
        retval
      end

      def get_dork_lists(list_path)
        Dir.foreach(list_path).select { |entry|
          !File.directory?(entry)
        }.select {  |entry|
          !File.readable?(entry)
        }.select { |file|
          file = File.open(list_path + '/' + file, 'r')
          begin
            file.readline =~ /NAME:/
          rescue
          ensure
            file.close
          end
        }.collect { |file|
          file_handle  = File.open(list_path + '/' + file, 'r')
          begin
            file_handle.readline.split(" ").drop(1).join(" ")
          rescue
          ensure
            file_handle.close
          end
        }
      end
    end
  end
end
