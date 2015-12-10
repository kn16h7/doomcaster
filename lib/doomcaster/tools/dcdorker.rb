module DoomCaster
  module Tools
    require 'google-search'
    require 'nokogiri'
    require 'pathname'
    require 'openssl'
    
    class DorkScanner < NetTool
      class SearchEngine
        include DoomCaster::Output
        include DoomCaster::HttpUtils

        def is_limited_res_se?
          false
        end
        
        def perform_search
          raise NotImplementedError
        end

        def handle_search_error(e)
        end
      end

      class GoogleApiSearchEngine < SearchEngine
        attr_accessor :query, :size, :offset, :language,
        
        def initialize(opts = {})
          @query = opts[:query]
          @size = opts[:size]
          @offset = opts[:offset]
          @language = opts[:language]
        end

        def is_limited_res_se?
          true
        end
        
        def perform_search
          info "Performing a search using Google API."

          results = []
          Google::Search::Web.new(:query => @query, :offset => @offset,
                                  :size => @size).each do |res|
            results << URI.parse(res.uri)
          end

          info "Search complete. Google API yield #{results.length} results"
          results
        end
      end

      class GooglePureSearchEngine < SearchEngine
        class GoogleBlockedSearchError < StandardError; end
        
        BASE_URI = 'https://www.google.com/search?'.freeze

        attr_accessor :query, :num, :offset
        
        def initialize(opts = {})
          @query = opts[:query]
          @num = opts[:num] || 100
          @offset = opts[:start] || 0
        end

        def perform_search
          params = ["q=#{@query}", "num=#{@num}", "start=#{@offset}"]
          complete_uri = BASE_URI + params.join("&")
          user_agent = DorkScanner::random_user_agent
          res = do_http_get(complete_uri, {'User-Agent' => user_agent})

          info "Performing a Google Search."
          verbose "The complete URL is #{complete_uri}"
          
          res_body = case res
                     when Net::HTTPOK
                       res.body
                     when Net::HTTPFound
                       location = res['Location']

                       raise GoogleBlockedSearchError \
                         if location.to_s =~ %r{https://ipv4.google.com/sorry/}
                       
                       redir = if location.is_a?(URI)
                                 location
                               else
                                 begin
                                   URI.parse(location)
                                 rescue InvalidURIError => e
                                   print_err_backtrace(e)
                                   URI.parse(URI.escape(location))
                                 end
                               end
                       
                       new_res = do_http_get(redir, {'User-Agent' => user_agent, 'Host' => redir.host})
                       new_res.body
                     end
          
          handle = Nokogiri::HTML(res_body)
          results = []
          handle.css('.r a').each { |link| results << link['href'] }
          results.map! { |link| sanitize_uri(link) }

          info "Search complete. Pure Google gave us #{results.length}"
          
          results
        end

        def handle_search_error(e)
          if e.is_a?(GoogleBlockedSearchError)
            fatal "Cannot perform a search: Google blocked our automated searches!"
          end
        end

        private
        def clean_uri_if_is_track_uri(uri)
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
          uri = clean_uri_if_is_track_uri(uri)
          unescaped = URI.unescape(uri).to_s
          unescaped.gsub(/ /, '+')
          URI.parse(unescaped)
        end
      end
      
      class BingSearchEngine < SearchEngine
        BASE_URI = 'http://www.bing.com/search?'
        BASE_API_URI = 'http://api.bing.net/json.aspx'
        MODES = ['pure', 'api']

        attr_accessor :query, :mode, :appid, :offset
        
        def initialize(opts = {})
          @query = opts[:query]
          @mode = opts[:mode] || 'pure'
          @appid = opts[:appid]
          @offset = opts[:offset] || 0
        end

        def perform_search
          if @mode == 'api'
          else
            uri_query = ["q=#{@query}", "first=#{@offset}", "filt=r"].join('&')
            search_uri = URI.parse(BASE_URI + uri_query)

            verbose "Performing a Bing search, the complete URI is #{search_uri.to_s}"

            search_res = do_http_get(search_uri, {'User-Agent' => random_user_agent()})

            links = []
            Nokogiri::HTML(search_res.body).css('.b_algo .b_title h2 a').each { |link|
              links << URI.parse(link)
            }
            links
          end
        end
      end

      class YahooSearchEngine < SearchEngine
      end

      SIMPLE_DESC = "A tool to look for vulnerable hosts based on a dork" +
        " to be used with an array of searh engines."

      DETAILED_DESC = "This tool takes: A dork provided by the user, a list of search engines\n" +
        "to be used and a great array of options to customize the vulnerability detection.\n\n" +
        "dcdorker is aimed to be a flexible, customizable and robust automatic dorker that works\n" +
        "on a lot of search engines and can merge the result of searches of several of them to\n" +
        "increase its efficiency.\n\n" +
        ""

      SEARCH_ENGINES = {
                        'google-api' => GoogleApiSearchEngine,
                        'google-pure' => GooglePureSearchEngine,
                        'bing-pure' => BingSearchEngine,
                        'bing-api' => nil,
                        'yahoo' => nil
                       }
      
      def initialize
        super('dcdorker', {})
        @vuln_sites = []
      end
      
      public
      def desc
        DoomCaster::ToolDesc.new(SIMPLE_DESC, DETAILED_DESC)
      end

      def before_run
        if @options[:search_engine]
          @options[:search_engine].each do |se|
            unless SEARCH_ENGINES.keys.include?(se)
              fail_exec "Cannot scan: Unknown search engine #{se}"
            end
          end
        end

        fail_exec "No check data was given" unless @options[:check_data]
        
        if @options[:check_data] !~ /^\$/
          filename = if @options[:check_data] =~ /^@/
                       @options[:check_data][1..-1]
                     else
                       @options[:check_data]
                     end

          if @options[:check_data] =~ /^@/
            fail_exec "Specified list file #{filename} does not exist" unless File.exists?(filename)
          else
            fail_exec "Specified list file #{filename} does not exist" \
              unless File.exists?(File.expand_path(filename, ENV['DOOMCASTER_HOME']))
          end
        end

        if @options[:http_method]
          fatalize_or_die "Unknown HTTP method: #{@options[:http_method]}" \
            unless HTTP_METHODS.include?(@options[:http_method])
        end
      end

      def do_run_tool
        if @options.empty?
          system('clear')
          Arts::dcdorker_banner
        end

        dork = unless @options[:dork]
                 ask_no_question "Digit your dork"
               else
                 @options[:dork]
               end
        
        vuln_amount = unless @options[:vuln_num]
                        read_num_from_user("How many vulnerable hosts do you want?")
                      else
                        @options[:vuln_num]
                      end


        configure_timeout()
        configure_follow_redirs()
        configure_max_redir_depth()
        configure_filtered_hosts()
        configure_search_engines()
        configure_check_data()
        configure_http_settings()
        configure_event_callbacks()

        run_dork_scan(dork, vuln_amount)
      end
      
      def parse_opts(parser, args = ARGV)
        @parser = parser
        @parser.separator ""
        @parser.separator "dcdorker options:"

        args.map! do |arg|
          String.remove_quotes_if_has_quotes(arg)
        end
        
        super(@parser)

        @parser.on("--dork <dork>", "Provide a pure dork") do |dork|
          @options[:dork] = dork
        end

        @parser.on("--search-engines <se>", "What search engines you want to use") do |search_engines|
          @options[:search_engines] = search_engines.split(',')
       end

        @parser.on("--se-options <opts>", "Set custom options for the search engines available") do |se_opts|
          @options[:se_options] = se_opts
        end

        @parser.on("--list-se", "List search engines available") do
          puts "The available search engines are:"
          SEARCH_ENGINES.keys.each { |se| puts se }
          exit if $execution_mode == :once
        end

        @parser.on("--check-data <list|value>", "The data DoomCaster will try to match inside the sites") do |opt|
          @options[:check_data] = opt
        end

        @parser.on("--check-options <options>", "Additional options for the checking") do |opt|
          @options[:check_options] = opt
        end

        @parser.on("--filtered-hosts <filtered-list>", "Set a list of filtered hosts from a file or a list\
separed by comas") do |list|
          @options[:filtered_hosts]
        end

        @parser.on("--max-redir-depth <num>", "Set the number of max redirection depth for a host") do |max|
          begin
            @options[:max_redir_depth] = Integer(max)
          rescue ArgumentError
            raise StandardError, "--max-redir-depth value must be a number!"
          end
        end

        @parser.on("--follow-redirections [yes|no|ask]", "Set default operation when a redirection is found") do |opt|
          @options[:follow_redirections] = opt
        end

        @parser.on("--disable-host-cache", "Makes DoomCaster test repeated hosts in a search result") do
          @options[:disable_host_cache] = true
        end

        @parser.on("--timeout <time>", "The time DoomCaster will wait for a successfull connection") do |time|
          begin
            @options[:timeout] = Integer(time)
          rescue ArgumentError
            raise StandardError, "--timeout value must be a number!"
          end          
        end

        @parser.on("--in-headers", "Look for the values in the HTTP headers of the response") do |opt|
          @options[:in_headers] = opt
        end

        @parser.on("--in-body", "Look for the values in the body of the response") do |opt|
          @options[:in_body] = opt
        end

        @parser.on("--on-vuln <action|cmd>", "Action to execute when a vulnerable site is detected") do |opt|
          @options[:on_vuln] = opt
        end

        @parser.on("--on-not-vuln <cmd>", "Action to execute when a not vulnerable site is detected") do |opt|
          @options[:on_not_vuln] = opt
        end

        uri_query_rplc_msg = "Specifies replacements for the values in the URI query obtained "
        uri_query_rplc_msg << "from a search"
        @parser.on("--uri-query-replace <new-query>", uri_query_rplc_msg) do |opt|
          @options[:uri_query_replace] = true
          @options[:uri_replaces] = opt
        end

        @parser.on("--http-method <method>", "What HTTP method use to do our requests") do |opt|
          @options[:http_method] = opt
        end

        @parser.on("--http-headers <header=value,header=value,...>", "Hand-configure HTTP headers for our requests") do |opt|
          @options[:http_headers] = opt
        end

        @parser.on("--http-body <body>", "The body of our requests") do |opt|
          @options[:http_body]
        end

        @parser.on("--help-se-options", "List search engines available and its options") do
          
        end

        @parser.on("--vuln-num <num>", "The number of vulnerable hosts you want to get") do |num|
          begin
            @options[:vuln_num] = Integer(num)
          rescue ArgumentError
            raise StandardError, "--vuln-num value must be a number!"
          end
        end

        @parser.on("--output <file>", "File to put the found sites") do |opt|
          @options[:output_file] = opt
        end

        @parser.on("--dont-giveup", "Continue doing searches until reach the asked number of targets") do |opt|
          @options[:dont_giveup] = true
        end
          
        @parser.on('--manual', 'Display a detailed explanation of this tool') do
          puts desc.detailed
          exit if $execution_mode == :once
        end
        
        @parser.on("--help", "This help message") do
          puts @parser
          exit if $execution_mode == :once
        end

        @parser.parse!(args)
      end      

      private
      def run_dork_scan(dork, num = 1)
        info "Starting dork scan..."

        @engines.each do |se|
          se.query = dork
        end

        error_num = 0

        loop do
          results = []
          @engines.each do |se|
            result = nil
            begin
              result = se.perform_search
              results += results
            rescue => e
              se.handle_search_error(e)
              error_num += 1
            end
          end

          fail_exec "Cannot dork: Attempt of search in all engines failed!" \
            if error_num == @engines.length

          info "Got a total of #{results.length} targets" if @engines.length > 1
          
          asked_num_reached = walk_results_list(results, num)

          if se_list_only_cont_limited_ses && @options[:dont_giveup]
            message = "Limit of results reached but number of asked vulnerable "
            message << "hosts not, and it'll not possible to perform a new search "
            message << "because the search engines you choose have a maximum limit "
            message << "of results."
            fatal message
            break
          end
          
          if !asked_num_reached && @options[:dont_giveup]
            message = "Limit of results reached but number of asked vulnerable "
            message << "hosts not. Doing a new search"
            info message
            
            @engines.each do |se|
              se.offset += 100
            end
          else
            break
          end
        end
        
        if @vuln_sites.length == num
          on_scan_complete(num)
        else
          on_scan_failed
        end
      end

      def se_list_only_cont_limited_ses
        contain = true
        @engines.each { |se| contain = false unless se.is_limited_res_se? }
        contain
      end
      
      def walk_results_list(results, num)
        domain_cache = []
        results.each do |res|
          if !domain_cache.include?(res.host) || @options[:disable_host_cache]
            info "Testing host #{res}"
            
            if res.query && @options[:uri_query_replace]
              res = perform_uri_replaces(res)
            elsif !res.query && @options[:uri_query_replace]
              info "URI #{res} has not any parameter to perform replacements. Therefore it will be ignored"
              puts
              next
            end
            
            if check_vuln(res)
              @vuln_sites << res
              good "Host #{res} seems vulnerable!"

              break if @vuln_sites.length == num
            else
              bad_info "Host #{res} seems to be not vulnerable"
            end
            domain_cache << res.host
            puts
          end
        end

        @vuln_sites.length == num
      end
      
      def perform_uri_replaces(uri)
        if @options[:uri_replaces]
          new_params = []

          if uri.query
            uri.query.split('&').each do |pair|
              pair = pair.split('=')
              next if pair.length == 1
              user_query = @options[:uri_replaces].clone
              param_val = pair[1]
              user_query.gsub!('%value%', param_val)
              param_val = user_query
              new_params << (pair[0] + '=' + param_val)
            end
          else
            return uri
          end

          uri.query = new_params.join('&')
        end
        uri
      end

      def configure_timeout
        @options[:timeout] = 60 unless @options[:timeout]
      end
      
      def configure_follow_redirs
        @options[:follow_redirections] = 'ask' unless @options[:follow_redirections]
      end

      def configure_max_redir_depth
        @options[:max_redir_depth] = 3 unless @options[:max_redir_depth]
      end

      def configure_filtered_hosts
        if @options[:filtered_hosts] && @options[:filtered_hosts] =~ /^@/
          @filtered_hosts = []
          File.open(@options[:filtered_hosts][1..-1]) do |f|
            f.each_line { |host| @filtered_hosts << host }
          end
        elsif @options[:filtered_hosts]
          @filtered_hosts = @options[:filtered_hosts].split(",")
        end
      end

      def configure_check_data        
        if @options[:check_data] =~ /^\$/
          @options[:check_data] = @options[:check_data][1..-1]
        elsif @options[:check_data] =~ /^@/
          filename = @options[:check_data][1..-1].clone
          @options[:check_data] = []
          File.open(filename, 'r') do |f|
            f.each_line do |line|
              @options[:check_data] << line.chomp!
            end
          end
        else
          filename = File.expand_path(@options[:check_data], ENV['DOOMCASTER_HOME'])
          @options[:check_data] = []
          File.open(filename, 'r') do |f|
            f.each_line do |line|
              @options[:check_data] << line.chomp!
            end
          end
        end
      end

      HTTP_METHODS = [ 'GET', 'POST', 'HEAD', 'TRACE', 'CONNECT', 'OPTIONS' , 'PUT', 'DELETE' ]

      def configure_http_settings
        unless @options[:http_method]
          verbose "HTTP method not given. Defaulting to GET."
          @options[:http_method] = 'GET'
        end

        @options[:http_method].upcase!

        headers_map = {}
        if @options[:http_headers]
          headers = @options[:http_headers].split(',')
          headers.each do |pair|
            name, val = pair.split('=')
            headers_map[name] = val
          end

          @options[:http_headers] = headers_map
        else
          @options[:http_headers] = {}
        end

        if @options[:http_body]
          if @options[:http_body] =~ /^@/
            @options[:http_body] = File.read(@options[:http_body][1..-1])
          end
        end

        if @options[:post_data]
          if @options[:http_method] != 'POST'
            info "Option --post-data is useless for HTTP GET method and will be ignored"
            return
          end

          if @options[:http_body]
            @options[:post_data] = @options[:http_body]
          else
            if @options[:post_data] =~ /^@/
              @options[:post_data] = File.read(@options[:post_data][1..-1])
            end
          end
        end
      end

      def configure_event_callbacks
        @on_vuln = nil
        @on_not_vuln = nil

        if @options[:on_vuln]
          if @options[:on_vuln] =~ /^@/
            @on_vuln = lambda { |uri|
              cmd = @options[:on_vuln].gsub('%uri%', uri)
              system(cmd)
            }
          end
        end

        if @options[:on_not_vuln]
          if @options[:on_not_vuln] =~ /^@/
            @on_not_vuln = lambda { |uri|
              cmd = @options[:on_not_vuln].gsub('%uri%', uri)
              system(cmd)
            }
          end
        end
      end

      def configure_search_engines
        unless @options[:search_engines]
          info "You have not given any search engine. Defaulting to Google API."
          @options[:search_engines] = ['google-api']
        end        

        @engines = []
        @options[:search_engines].each_with_index do |se, idx|
          @engines[idx] = SEARCH_ENGINES[se].new()
        end

        return unless @options[:se_options]

        @options[:se_options].split(";").each_with_index do |se_opts, idx|
          engine_name, engine_opts = se_opts.split(":")
          
          engine_opts.split(",").each do |opt|
            opt_name, opt_val = opt.split("=")
            case engine_name
            when 'google-api'
              case opt_name
              when 'offset'
                offset = 0
                begin
                  offset = Integer(opt_val)
                rescue ArgumentError
                  fail_exec '"offset" parameter must be a number!'
                end

                fail_exec '"offset" cannot be greater than 64 due to Google API limitations!' \
                  if offset > 64

                @engines[idx].offset = offset
              when 'size'
                size = opt_val

                fail_exec 'Invalid "size" option for Google API: must be "small" or "large"' \
                  if size != 'large' && size != 'small'

                @engines[idx].size = size.to_sym
              when 'language'
                @engines[idx].language = opt_val.to_sym
              else
                fail_exec "Unkown option #{opt_name} for search engine #{engine_name}"
              end
            when 'bing-api'
              case opt_name
              when 'appid'
                unless opt_val
                  fail_exec "Bing API mode requires an AppID to perform searches!"
                end
                @engines[idx].appid = opts['appid']
                end
            when 'bing-pure'
              case opt_name
              when 'first'
                begin
                  @engines[idx].first = Integer(opt_val)
                rescue ArgumentError
                  fail_exec '"first" parameter must be a number'
                end
              end
            when 'yahoo'
            end
          end
        end
      end      

      def DorkScanner.random_user_agent
        user_agents_file = ENV['DOOMCASTER_HOME'] + '/user-agents'
        
        unless File.exists?(user_agents_file)
          fatalize_or_die "Cannot scan: File with list of user agents not found."
        end
        
        user_agents = File.read(user_agents_file).split("\n")
        user_agents[rand(user_agents.length - 1)]
      end

      def str_matches_any?(str, values)
        values.each do |val|
          return true if str =~ Regexp.new(val)
        end
        false
      end

      def vals_are_in_body?(target)
        if @options[:check_data].is_a?(String)
          str_matches_any?(target, [@options[:check_data]])
        else
          str_matches_any?(target, @options[:check_data])
        end
      end

      def vals_are_in_headers?(target)
        target.each do |name, val|
          arg = if @options[:check_data].is_a?(String)
                  [@options[:check_data]]
                else
                  @options[:check_data]
                end

          return true if str_matches_any?(val, arg)
        end
        false
      end

      def check_vuln(target, curr_redir_depth = 0)
        if curr_redir_depth == @options[:max_redir_depth]
          info "Maximum redirection depth reached, giving up of this host"
          return false
        end
        
        conn_tries = 0

        while true
          begin
            case @options[:http_method]
            when 'GET'
              @options[:http_headers]['User-Agent'] = DorkScanner::random_user_agent
              res = do_http_get(target, @options[:http_headers], @proxy,
                                {
                                 :open_timeout => @options[:timeout],
                                 :read_timeout => @options[:timeout]
                                })
              break
            when 'POST'
              
            end
          rescue Net::OpenTimeout
            if conn_tries < 5
              bad_info "Connection to #{target} timed out. Retrying..."
              conn_tries += 1
            else
              bad_info "Max number of retries reached. Giving up of this host"
              return false
            end
          rescue Net::ReadTimeout
            if conn_tries < 5
              bad_info "Host #{target} took to long to response. Retrying..."
              conn_tries += 1
            else
              bad_info "Max number of retries reached. Giving up of this host"
              return false
            end
          rescue SocketError => e
            print_err_backtrace(e)
            if conn_tries < 5
              bad_info "Network error while trying to connect (#{e}). Retrying..."
              conn_tries += 1
            else
              bad_info "Max number of retries reached. Giving up of this host"
              return false
            end
          rescue StandardError => e
            print_err_backtrace(e)
            message = "An unknown error was caught: #{e.class.to_s + " :: " + e.to_s}."
            message << " Because we don't know how to proceed, we'll give up of this host"
            fatal message
            return false
          end
        end

        case res
        when Net::HTTPOK
          if @options[:in_body] && @options[:in_headers]
            vals_are_in_body?(res.body) || val_is_in_headers?(res)
          elsif @options[:in_body] || (!@options[:in_body] && !@options[:in_headers])
            vals_are_in_body?(res.body)
          else
            val_is_in_headers?(res)
          end
        when Net::HTTPForbidden
          bad_info "#{target} is inacessible! (403)"
          return false
        when Net::HTTPFound, Net::HTTPMovedPermanently
          vuln = false
          if @options[:follow_redirections] == 'ask' || @options[:follow_redirections] == 'yes'
            location = res['Location']

            new_uri = nil
            if location.is_a?(URI)
              new_uri = location
              new_uri.scheme = 'http' unless new_uri.scheme
            else
              new_uri = URI.parse(location)
              unless new_uri.host
                new_uri.host = target.host
                new_uri.scheme = 'http' unless new_uri.scheme
              end
            end

            new_uri = perform_uri_replaces(new_uri)
            
            if @options[:follow_redirections] == 'ask'
              ask "Got a redirection to #{new_uri}. Do you want to follow it?", ['y','n'] do |arr|
                arr.on('y') do
                  normal_info "Ok!"
                  vuln = check_vuln(new_uri, curr_redir_depth + 1)
                end

                arr.on('n') do
                  normal_info "Ok..."
                  vuln = false
                end
              end
            else
              info "#{target} redirected to #{new_uri}"
              vuln = check_vuln(new_uri, curr_redir_depth + 1)
            end
          else
            info "Ignoring redirection gotten from #{target}"
          end

          return vuln
        when Net::HTTPNotFound
          bad_info "Resource/directory in #{target} not found! (404)"
          return false
        else
          bad_info "Received an unhandable HTTP status: #{res.code}"
          return false
        end
      end
      
      def on_scan_complete(count)
        good "Scanning complete, #{count} of sites that seem vulnerable were found," +
          "as you asked."
        good "The sites are:"
        @vuln_sites.each { |site|
          good site
        }

        if @options[:output_file]
          info "Saving the sites in the file #{@options[:output_file]}"
          File.open(@options[:output_file], "a") do |f|
            @vuln_sites.each { |site|
              f.puts site
            }
          end
        end
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

        if @options[:output_file]
          info "Saving the sites in the file #{@options[:output_file]}"
          File.open(@options[:output_file], "a") do |f|
            @vuln_sites.each { |site|
              f.puts site
            }
          end
        end
      end
    end
  end
end
