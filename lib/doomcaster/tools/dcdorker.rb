module DoomCaster
  module Tools
    require 'google-search'
    require 'nokogiri'
    require 'timeout'
    require 'pathname'
    require 'openssl'
    
    class DorkScanner < NetTool
      class SearchEngine
        include DoomCaster::Output
        include DoomCaster::HttpUtils

        def perform_search
          raise NotImplementedError
        end
      end

      class GoogleApiSearchEngine < SearchEngine
        def initialize(opts = {})
          @query = opts[:query]
        end
        
        def perform_search
          result = []
          Google::Search::Web.new(:query => @query).each do |res|
            result << res.url
          end
          result
        end
      end

      class GooglePureSearchEngine < SearchEngine
        BASE_URI = 'https://www.google.com/search?'.freeze

        attr_accessor :query, :num, :start
        
        def initialize(opts = {})
          @query = opts[:query]
          @num = opts[:num] || 100
          @start = opts[:start] || 0
        end

        def perform_search
          params = ["q=#{@query}", "num=#{@num}", "start=#{@start}"]
          complete_uri = BASE_URI + params.join("&")
          user_agent = random_user_agent
          res = do_http_get(complete_uri, {'User-Agent' => user_agent})

          verbose "A Google search will be done. The complete URL is #{complete_uri}"
          
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
          handle.css('.r a').each { |link| results << link['href'] }
          results.map! { |link| sanitize_uri(link) }
          results
        end

        private
        #Google sometimes do not give us normal URIs, but Google's URI, that
        #is used by Google to track us
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
        
        def random_user_agent
          user_agents_file = ENV['DOOMCASTER_HOME'] + '/wordlists/user-agents'
          
          unless File.exists?(user_agents_file)
            fatalize_or_die "Cannot scan: File with list of user agents not found."
          end
          
          user_agents = File.read(user_agents_file).split('\n')
          user_agents[rand(user_agents.length - 1)]
        end
      end
      
      class BingSearchEngine < SearchEngine
        BASE_URI = 'http://www.bing.com/search?'
        BASE_API_URI = 'http://api.bing.net/json.aspx'
        MODES = ['pure', 'api']

        attr_accessor :query, :mode, :appid, :first
        
        def initialize(opts = {})
          @query = opts[:query]
          @mode = opts[:mode] || 'pure'
          @appid = opts[:appid]
          @first = opts[:first] || 0
        end

        def perform_search
          if @mode == 'api'
          else
            uri_query = ["q=#{@query}", "first=#{@first}", "filt=r"].join('&')
            search_uri = URI.parse(BASE_URI + uri_query)

            verbose "A Bing search will be made, the complete URI is #{search_uri.to_s}"

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

      SEARCH_ENGINES = {
                        'google' => [GooglePureSearchEngine, GoogleApiSearchEngine],
                        'bing' => BingSearchEngine,
                        'Yahoo!' => nil
                       }
      
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

        if !@options[:search_engine]
          info "You have not given any search engine. Defaulting to Google."
          @options[:search_engine] = 'google'
        elsif @options[:search_engine] != 'google'
          @engine = SEARCH_ENGINES[@options[:search_engine]].new()
        end

        process_search_engine_options()

        start_dork_scan(dork, vuln_amount)
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

        @parser.on("--search-engine <se>", "What search engine you want to use") do |search_engines|
          @options[:search_engine] = search_engines
        end

        @parser.on("--se-options <opts>", "Set custom options for the search engines available") do |se_opts|
          @options[:se_options] = se_opts
        end

        @parser.on("--list-se", "List search engines available") do
        end

        @parser.on("--help-se-options", "List search engines available and its options") do
        end

        @parser.on("--vuln-num", "The number of vulnerable hosts you want to get") do |num|
          @options[:vuln_num] = num
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
      def start_dork_scan(dork, num = 1)
        info "Starting dork scan..."

        @engine.query = dork
        found_hosts = []
        domain_cache = []
        loop do
          results = @engine.perform_search
          results.each do |res|
            unless domain_cache.include?(res.host)
              @vuln_sites << res if check_vuln(res)
            end
          end

          
          break unless @options[:dont_giveup] || found_hosts.length == num
        end
      end

      def check_vuln(target)
      end
      
      def process_search_engine_options
        return unless @options[:se_options]

        opts = {}
        @options[:se_options].split(' ').each do |pair|
          key, val = pair.split('=')
          opts[key] = val
        end
        
        case @options[:search_engine]
        when 'google'
          if opts['mode']
            case opts['mode']
            when 'api'
              @engine = SEARCH_ENGINES[@options[:search_engine]][1].new()
            when 'direct'
              @engine = SEARCH_ENGINES[@options[:search_engine]][0].new()
            else
              fail_exec "Invalid mode (#{opts['mode']}) for Search Engine: Google"
            end
          else
            info "Google mode not specified, defaulting to API"
            @engine = SEARCH_ENGINES[@options[:search_engine]][1].new()
          end

          if opts['start']
            begin
              @engine.start = Integer(opts['start'])
            rescue ArgumentError
              fail_exec "\"start\" parameter must be a number"
            end
          end

          if opts['num']
            begin
              @engine.start = Integer(opts['num'])
            rescue ArgumentError
              fail_exec "\"num\" parameter must be a number"
            end
          end
        when 'bing'
          case opts['mode']
          when 'api'
            unless opts['appid']
              fail_exec "Bing API mode requires an AppID to perform searches."
            end
            @engine.appid = opts['appid']
          when 'direct'
            if opts['first']
              begin
                @engine.first = Integer(opts['first'])
              rescue ArgumentError
                fail_exec "\"first\" parameter must be a number"
              end
            end
          end
        when 'yahoo'
        end
      end      

      def DorkScanner.random_user_agent
        user_agents_file = ENV['DOOMCASTER_HOME'] + '/wordlists/user-agents'
        
        unless File.exists?(user_agents_file)
          fatalize_or_die "Cannot scan: File with list of user agents not found."
        end
        
        user_agents = File.read(user_agents_file).split('\n')
        user_agents[rand(user_agents.length - 1)]
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
