module DoomCaster
  module Tools
    require 'google-search'
    require 'nokogiri'
    require 'timeout'
    
    class DorkScanner < NetTool

      class GoogleSearch
        include DoomCaster::Output
        include DoomCaster::HttpUtils

        class ResponseData
          attr_reader :uri
          
          def initialize(uri)
            @uri = uri
          end
        end

        ## API Method: Use Google API to perform searches.
        ## Pure Method: Perform searches directly on Google page.
        GOOGLE_METHODS = ['pure', 'api']

        class GoogleBlockedSearchError < StandardError; end
        
        BASE_URI = 'https://www.google.com/search?'.freeze
        
        attr_accessor :start
        attr_accessor :query
        attr_accessor :num
        
        def initialize(opts = {})
          @query = opts[:query]
          @num = opts[:num] || 100
          @start = opts[:start] || 0
        end
        
        def do_google_search
          params = ["q=#{@query}", "num=#{@num}", "start=#{@start}"]
          complete_uri = BASE_URI + params.join("&")
          user_agent = random_user_agent
          res = do_http_get(complete_uri, {'User-Agent' => user_agent})

          res_body = case res
                     when Net::HTTPOK
                       res.body
                     when Net::HTTPFound
                       location = res['Location']

                       raise GoogleBlockedSearchError if location.to_s =~ %r{https://ipv4.google.com/sorry/}
                       
                       redir = if location.is_a?(URI)
                                 location
                               else
                                 begin
                                   URI.parse(location)
                                 rescue InvalidURIError
                                   URI.parse(URI.escape(location))
                                 end 
                               end
                       
                       new_res = do_http_get(redir, {'User-Agent' => user_agent, 'Host' => redir.host})
                       new_res.body
                     end
          
          handle = Nokogiri::HTML(res_body)
          results = []
          handle.css('.r a').map { |link|
            results << ResponseData.new(link['href'])
          }
          results
        end

        private
        #We need to do this because for some reason Google does not delivers us
        #clean URIs when the user agent is not a known Browser.
        def random_user_agent
          user_agents_file = ENV['DOOMCASTER_HOME'] + '/wordlists/user-agents'

          unless File.exists?(user_agents_file)
            if $execution_mode == :once
              die "Cannot scan: File with list of user agents not found.".bg_red
            else
              fatal "Cannot scan: File with list of user agents not found."
            end
          end

          user_agents = File.read(user_agents_file).split('\n')
          user_agents[rand(user_agents.length - 1)]
        end
      end
      
      def initialize
        super('dcdorker', {})
        @vuln_sites = []
        @domain_cache = []
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

      def print_manual
        puts desc.detailed
      end

      def run
        list_path = unless @options[:list_path]
                      ENV['DOOMCASTER_HOME'] + "/wordlists/dork-lists"
                    else
                      @options[:list_path]
                    end

        if get_dork_lists(list_path).empty?
          if $execution_mode == :once
            die "Cannot perform a dork scan: No lists available.".bg_red
          else
            fatal "Cannot perform a dork scan: No lists available."
          end
        end
        
        system('clear')
        $shell_pwd = 'dcdorker'
        Arts::dcdorker_banner
        
        domain = get_domain
        dork = get_dork(list_path)
        sanitized_dork = sanitize_dork(dork)
        complete_dork = domain + sanitized_dork
        
        good "The complete dork is: #{complete_dork}"
        amount = nil
        loop do
          begin
            answer = ask_no_question "How many vulnerable sites do you want?"
            amount = Integer(answer)
            break
          rescue ArgumentError
            puts "Invalid Input!".bg_red
          end
        end
        
        start_dork_scan(complete_dork, amount)
      end

      def parse_opts(parser, args = ARGV)
        @parser = parser
        @parser.separator ""
        @parser.separator "dork-scanner options:"
        
        super(@parser)
        
        @parser.on("--list-path <path>", "The path where to look up for dork lists") do |path|
          @options[:list_path] = path
        end

        @parser.on("--google-method <method>", "What method use to perform searches on Google") do |opt|
          @options[:google_mode] = opt

          unless GoogleSearch::GOOGLE_METHODS.include?(opt)
            if $execution_mode == :once
              fatal "Cannot perform a dork scan: Unknown mode: #{opt}"
              fatal "The available modes are: api and pure".bg_red
              exit 1
            else
              fatal "Cannot perform a dork scan: Unknown mode: #{opt}"
              fatal "The available modes are: api and pure."
            end
          end
        end

        @parser.on('--manual', 'Display a detailed explanation of this tool') do
          print_manual
          exit if $execution_mode == :once
        end
        
        @parser.on("--help", "This help message") do
          puts @parser
          exit if $execution_mode == :once
        end
        
        @parser.parse!(args)
      end

      private
      def get_domain
        question  = "Digit the domain you want to scan (e.g. .com, .net, .org, etc). "
        question << "If you don't care about the domain, just hit return."
        ask_no_question question
      end

      def get_dork(list_path)
        info "Select the dork list you want to use, the available lists are:"
        lists = get_dork_lists(list_path)
        puts ""
        lists.each_index { |idx|
          puts " [#{idx}] #{lists[idx]}".red.bold
        }
        info "Custom dork"
        
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
          info "Ok! Loading wordlist."
          in_memory_list = load_wordlist(list_path, list)

          stop = false
          until stop
            info "Selecting a random dork"

            size = in_memory_list.length
            what_dork = in_memory_list[Integer(rand(size))]
            
            info "Selected dork is #{what_dork}"

            ask "Do you want to use this dork? [y/n]", ['y', 'n'] do |opts|
              opts.on('y') do |opt|
                stop = true
              end
              
              opts.on('n') do |opt|
                stop = false
              end
            end
          end
        end
        what_dork
      end
      
      def load_sql_errors_list
        sql_list_file = ENV['DOOMCASTER_HOME'] + '/wordlists/sql-errors-list'
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

      #Google sometimes do not give us normal URIs, but Google's URI, that
      #is used by Google to track
      def clean_uri_if_strange(uri)
        str_uri = uri.to_s
        if str_uri =~ %r{/.*\?url=}
          str_uri.gsub(/\/.*\?url=/ , '').gsub(/&sa=.*/, '')
        elsif str_uri =~ %r{/url\?q=.*}
          str_uri.gsub(%r{/url\?q=}, '').gsub(%r{&sa=.*}, '')
        else
          str_uri
        end
      end

      def sanitize_uri(uri)
        uri = clean_uri_if_strange(uri)
        URI.parse(URI.unescape(uri))
      end

      def process_res(uri)
        info "Processing #{uri}..."
        info "Verifying if #{uri} is alright..."

        unless uri.query
          bad_info "#{uri} lacks of a parameter to check vulnerability"
          bad_info "DoomCaster will consider this site seems not vulnerable"
          return false
        end
        
        http_res = nil
        begin
          Timeout::timeout(60) do
            http_res = do_http_get(uri, nil, @proxy)
          end
        rescue Errno::ETIMEDOUT
          fatal "Connection to #{uri} timed out, going to the next"
          return false
        rescue Errno::ECONNREFUSED
          fatal "#{uri} refused our connection"
          return false
        rescue Net::HTTPBadResponse => e
          bad_info "Server gave to us an bad response: #{e}, going to the next"
          return false
        rescue SocketError => e
          bad_info "Network error while trying to test (#{e}), going to the next"
          return false
        rescue Timeout::Error
          bad_info "Site took a very long time to download, giving up of this site and going to the next"
          return false
        end

        if http_res.code =~ /200/
          good "#{uri} is ok!"
          info "DoomCaster will check for vulnerability."

          vuln_uri = uri.clone

          params = get_parameters(uri.query)

          if params.length > 1
            good "This URI has more than one parameter! Doomcaster will check for vulnerabilities in each one."
          end

          vuln_detected = false
          params.each do |param|
            vuln_uri.query = vuln_parameter(uri.query, param)

            begin
              Timeout::timeout(60) do
                http_res = do_http_get(vuln_uri)
              end
            rescue Timeout::Error
              bad_info "Site took a very long time to download, giving up of this site and going to the next"
              return false
            rescue Net::ReadTimeout
              fatal "Connection timed out, going to the next"
              return false
            end

            if check_sql_error(http_res.body)
              good "The parameter #{param} of #{uri} seems vulnerable!"
              @vuln_sites << uri
              vuln_detected = true
            else
              bad_info "Parameter #{param} of #{uri} seems not vulnerable."
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
          redirect_processed = false
          until redirect_processed
            ask "Do you want to follow it? [y/n]: ", ['y', 'n'] do |opts|
              opts.on('y') do
                encoded_redirection = URI.escape(redirection.to_s)
                process_res(URI.parse(encoded_redirection))
                redirect_processed = true
              end
              
              opts.on('n') do
                puts " [*] Ok.".bold.red
                redirect_processed = true
              end
            end
          end
        elsif http_res.code =~ /404/
          fatal "#{uri} is not ok: received a 404"
        else
          bad_info "DoomCaster received an unhandable HTTP status: #{http_res.code}"
        end
      end

      def on_scan_complete(count)
        good "Scanning complete, #{count} of sites that seem vulnerable were found," +
          "as you asked."
        good "The sites are:"
        @vuln_sites.each { |site|
          good site
        }
      end

      def on_scan_failed
        puts "\n"
        message =  "It seems that this dork didn't give us sufficient results." +
          " It may be because this dork is unefficient and Google cannot provide "  +
          "a good number of sites to test. I recommend you to try other dorks."
        
        bad_info message
        
        if @vuln_sites.length > 0
          puts ""
          good "But anyway, some vulnerable sites were found!"
          good "The sites are:"
          @vuln_sites.each { |site|
            good site
          }
        end
      end

      def do_dork_scan(query, num, start)
        google_constant = nil
        if @options[:google_mode] == 'api'
          google_constant = Google::Search::Web
        else
          google_constant = GoogleSearch
        end
        
        begin
          info "Doing a Google Search..."
          count = 0
          results = []

          if @options[:google_mode] == 'pure'
            google = google_constant.new(:query => query, :start => start)
          else
            info "Ignoring opiton \"start\" because we are in API mode."
            google = google_constant.new(:query => query)
          end

          if @options[:google_method] == 'api'
            google.each do |res|
              results << res
            end
          else
            google.do_google_search.each do |res|
              results << res
            end
          end
          
          info "Search completed, Google gave us #{results.length} results."          

          if results.length == 0
            if $execution_mode == :once
              die "Cannot perform a scan: Google gave 0 results.".bg_red
            else
              fatal "Cannot perform a scan: Google gave 0 results."
            end
          end

          info "Sanitizing results..."
          results.map! do |res|
            sanitize_uri(res.uri)
          end
          info "Results sanitized."
          
          bad_info "It seems that Google cannot give sufficient results." if results.length < num
          info "Processing results..."
          
          results.each do |uri|
            next if @domain_cache.include?(uri.host)
            
            puts "\n"
            @domain_cache << uri.host
            begin
              count += 1 if process_res(uri)
            rescue StandardError => e
              fatal "Some unhandable error has happened: #{e}"
            end

            $stdout.flush
            if count == num
              puts "\n"
              on_scan_complete(count)
              return
            end
          end
        rescue IOError
          DoomCaster::die " [FATAL] I/O Error while scanning.".bg_red
        rescue GoogleSearch::GoogleBlockedSearchError
          message = "Cannot perform a scan: Google detected our automated searches and has blocked "
          message << "it for a while."
          fatal message
          
          ask "Do you want to try a scan with the Google API method? [y/n]", ['y', 'n'] do |opts|
            opts.on('y') do
              @options[:google_mode] = 'api'
              do_dork_scan_api(query, num)
              return
            end
            
            opts.on('n') do
              return
            end
          end
        end
        if @options[:google_mode] == 'api'
          on_scan_failed
        else
          message = "It seems that our results has reached the limit and DoomCaster were "
          message << "not able to get the amount of results you asked."
          bad_info message

          question = "What do you want to do? "
          question << "[(e)nd the scanning, "
          question << "(c)ontinue this times doing a search looking for the futher results]"
          ask question, ['e', 'c'] do |opts|
            opts.on('e') do
              on_scan_failed
              return
            end
            opts.on('c') do
              do_dork_scan(query, num, start + 100)
            end
          end
        end
      end

      def start_dork_scan(dork, num = 1)
        good "Starting dork scan..."
        query = "inurl:" + dork

        unless @options[:google_mode]
          info "Google method not specified. Defaulting to API."
          @options[:google_mode] = 'api'
        end

        do_dork_scan(query, num, 0)
      end

      def sanitize_dork(dork)
        unless dork =~ /^\//
          dork = '/' + dork
        end
        dork
      end
      
      def custom_dork
        ask_no_question "Digit your custom dork: "
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
        absolute_path = if list_path.start_with?('/')
                          list_path
                        else
                          File.expand_path(list_path)
                        end
        
        Dir.foreach(absolute_path).select { |entry|
          !File.directory?(File.expand_path(entry, absolute_path))
        }.select {  |entry|
          File.readable?(File.expand_path(entry, absolute_path))
        }.select { |file|
          file = File.open(File.expand_path(file, absolute_path), 'r')
          begin
            file.readline =~ /NAME:/
          rescue
          ensure
            file.close
          end
        }.collect { |file|
          file_handle  = File.open(File.expand_path(file, absolute_path), 'r')
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
