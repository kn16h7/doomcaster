module DoomCaster
  module Tools
    class AdminFinder < NetTool
      SIMPLE_DESC = "A tool for find the administrative page in websites.\n\n"
      DETAILED_DESC = "This tool takes an URL pointing to a site the user provides\n" +
        "and simply looks for an administrative web page based on a list of very common\n" +
        "administrative pages.\n\n" +
        "Command line options:\n" +
        "--host <host>\n" +
        "Use this option to provide a site directly to this tool. The host is simply the\n" +
        "target of the admin page look up.\n\n" +
        "--list <list>\n" +
        "The name of the list you want to use to do the look up. The list is normally a text\n" +
        "file containing an URI directory/resource representing a possible admin page, which is\n" +
        "a very common or known name for an administrative panel in a site. This tool will build\n" +
        "an URL joining the given site host and the resource/directory in each line, check if it's\n" +
        "accessible (does not give a 404, 500, 403 or any similar HTTP response) and, if it is, check\n" +
        "if the page content contains some hint suggesting that it's an admin page.\n\n" +
        "--list-path <path>\n" +
        "An directory alternative to the default directory inside DOOMCASTER_HOME where this tool will\n" +
        "look up for lists. If this option were not provided, this tool will look up for lists in: DOOMCASTER_HOME\n" +
        "/admin-lists.\n\n" +
        "--help\n" +
        "Display a simple help message.\n\n" +
        "--manual\n" +
        "Display this manual."
      
      def initialize
        super('dc-admin-buster', {})
      end

      public
      def desc
        DoomCaster::ToolDesc.new(SIMPLE_DESC, DETAILED_DESC)
      end

      def before_run
        @site = @options[:host]
        @list = @options[:list]

        list_path = unless @options[:list_path]
                      @options[:list_path] = File.expand_path('admin-lists', ENV['DOOMCASTER_HOME'])
                      @options[:list_path]
                    else
                      @options[:list_path]
                    end

        verbose "Path where lists will be looked up is #{list_path}"
        
        @lists = get_lists(list_path)
        fail_exec self.name, "Cannot scan site: No list available" if @lists.empty?

        if @options[:list]
          unless lists.include?(@options[:list])
            fail_exec "Cannot scan site: The given list was not found"
          end
        end
      end
      
      def do_run_tool
        system('clear')
        Arts::dc_admin_buster_banner
        
        unless @site
          message = "Enter the website you want to scan "
          message <<  "(e.g.: www.domaine.com or www.domaine.com/path\):"
          @site = ask_no_question message
        end
        
        unless @list
          print "\n"
          info "Enter the list you want to use."
          info "The available lists are:\n"

          @lists.each_index { |idx|
            puts " [#{idx}] #{@lists[idx]}".red.bold
          }

          loop do
            idx = read_num_from_user()
            unless @lists[idx]
              puts " Unknown list!".bg_red
            else
              @list = @lists[idx]
              break
            end
          end
        end

        begin
          @site = URI.parse(@site)
        rescue URI::InvalidURIError => e
          print_err_backtrace(e)
          fail_exec "Cannot scan: #{site} is not a valid URL."
        end

        if @site.scheme
          if @site.scheme != 'http' && @site.scheme != 'https'
            fail_exec "Cannot scan: URI does not point to a site"
          end
        else
          @site = URI.parse('http://' + @site.to_s)
        end

        puts "\n"
        info "The website: #{@site}"
        info "List to be used: #{@list}"
        info "Scan of the admin control panel is progressing...\n"
        search_generic(@site, @list)
      end

      def parse_opts(parser, args = ARGV)
        @parser = parser

        @parser.separator ""
        @parser.separator "dc-admin-buster options:\n"

        args.map! do |arg|
          if arg =~ /^--/
            arg
          end
          
          String.remove_quotes_if_has_quotes(arg)
        end
        
        super(@parser)
        @parser.on("--host <host>", "The target host to be scanned") do |host|
          @options[:host] = host
        end

        @parser.on("--list <list>", "The list to be used") do |list|
          @options[:list] = list
        end

        @parser.on("--list-path <path>", "The path where to look up for lists") do |path|
          @options[:list_path] = path
        end

        @parser.on("--help", "Print this help message") do
          puts @parser
          exit if $execution_mode == :once
        end

        @parser.on("--manual", "Print a detailed help message") do
          puts desc.detailed
          exit if $execution_mode == :once
        end
        
        @parser.parse!(args)
      end

      private
      def check_site(http_res)
        http_res.body =~ /Username/ ||
          http_res.body =~ /Password/ ||
          http_res.body =~ /username/ ||
          http_res.body =~ /password/ ||
          http_res.body =~ /USERNAME/ ||
          http_res.body =~ /PASSWORD/ ||
          http_res.body =~ /Senha/ ||
          http_res.body =~ /senha/ ||
          http_res.body =~ /Personal/ ||
          http_res.body =~ /Usuario/ ||
          http_res.body =~ /Clave/ ||
          http_res.body =~ /Usager/ ||
          http_res.body =~ /usager/ ||
          http_res.body =~ /Sing/ ||
          http_res.body =~ /passe/ ||
          http_res.body =~ /P\/W/ ||
          http_res.body =~ /Admin Password/ ||
          http_res.body =~ /Login/ ||
          http_res.body =~ /login/
      end

      def search_generic(site, list_file_name)
        found = false

        list_path = @options[:list_path]
        start_path = expand_list_path(list_path)
        list_file = File.expand_path(list_file_name, start_path)
        
        File.open(list_file) do |f|
          tries = 0
          
          f.each_line do |line|
            line.chomp!
            try_uri = site.clone
            
            if line =~ /\?/
              path, query = line.split('?')
              line = path
              try_uri.query = query
            end

            if try_uri.path
              if try_uri.path.end_with?('/') && line.start_with?('/')
                line = line[1..-1]
              elsif !try_uri.path.end_with?('/') && !line.start_with?('/')
                line = '/' + line
              end
              try_uri.path += line
            else
              line = '/' + line unless line.start_with?('/')
              try_uri.path = line
            end
            
            normal_info "Trying: #{try_uri}"
            res = nil
            begin
              res = do_http_get(try_uri, @proxy, nil,
                                {
                                 :open_timeout => 60,
                                 :read_timeout => 60
                                })
            rescue Net::OpenTimeout, Net::ReadTimeout
              if tries != 5
                fatal "Request timed out, retrying..."
                tries += 1
                retry
              else
                message = "Request timed out and max number of retries reached. "
                message << "Giving up of this host"
                fatal message
                tries = 0
                next
              end
            rescue SocketError => e
              print_err_backtrace(e)
              fatal "Network error while attempting (#{e})"
              next
            end
            
            if res.code =~ /404/
              bad_info "Not Found <- #{try_uri}"
              next
            elsif res.code =~ /301/ || res.code =~ /302/
              location = res['Location']

              verbose "#{try_uri} redirected to the possible URI or resource #{location}"

              new_uri = nil
              if location.is_a?(URI)
                new_uri = location
                new_uri.scheme = 'http' unless new_uri.scheme
              else
                new_uri = URI.parse(location)
                unless new_uri.host
                  new_uri.host = try_uri.host
                  new_uri.scheme = 'http'
                end
              end
              
              normal_info "Possible admin page found in: #{new_uri}. But DoomCaster will check!"
              new_res = do_http_get(new_uri, @proxy, nil,
                                    {
                                     :open_timeout => 60,
                                     :read_timeout => 60
                                    })
              
              if check_site(new_res)
                good "Found -> #{new_uri}\n"
                good "But this admin page is actually in another place\n"
                good "Congratulation, this admin login page is working!\n"
                good "Good luck from SuperSenpai.\n"
                found = true
              else
                bad_info "False positive: #{new_uri} is not a valid admin page."
                next
              end
            elsif res.code =~ /401/
              message = "A posssible admin page was found in: #{try_uri}, but it seems that this site use a different"
              message << " style of authentication for its administrators. And we are unautorized."
              info message
              info "I recommend you to see what this page is before back and answer the following question."
              ask "What do you want to do? [(c)ontinue/(co)nsider as found]", ['c', 'co'] do |opts|
                opts.on('c') do
                  found = false
                  next
                end
                
                opts.on('co') do
                  found = true
                  good "Ok! I'll consider the admin page as found!"
                  puts "\n"
                  good "Found -> #{try_uri}\n"
                  good "Congratulation, this admin login page is working.\n"
                  good "Good luck from SuperSenpai.\n"
                end
              end
            elsif res.code =~ /403/
              info "A possible admin page was found in: #{try_uri}, but we are forbidden of visiting this page."
              question = "What do you want to do? [(c)ontinue/(co)nsider as found]"
              ask question, ['c', 'co'] do |opts|
                opts.on('c') do
                  found = false
                  next
                end

                opts.on('co') do
                  found = true
                  good "Ok! DoomCaster will consider the admin page as found!"
                  puts "\n"
                  good "Found -> #{try_uri}\n"
                  good "Congratulation, this admin login page is working.\n"
                  good "Good luck from SuperSenpai.\n"
                end
              end
            elsif res.code =~ /200/ && check_site(res)
              good "Found -> #{try_uri}\n"
              good "Congratulation, this admin login page is working.\n"
              good "Good luck from SuperSenpai.\n"
              found = true
            else
              bad_info "Not Found <- #{try_uri}"
            end
            
            if found
              warn "WARNING: It's recommended to you to check if the page is really what you want!"

              ask "Desired page found. Do you want to continue? [y/n]: ", ['y','n'] do |opts|
                opts.on('y') do
                  puts "Ok...".green.bold
                  found = false
                end
                opts.on('n') do
                  puts "Ok!".green.bold
                  return
                end
              end
            end
            tries = 0
          end
        end
      end

      def expand_list_path(list_path)
        absolute_path = if list_path.start_with?('/')
                          list_path
                        else
                          File.expand_path(list_path)
                        end
        
        fail_exec "list_path is not a directory!" unless File.directory?(absolute_path)
        absolute_path
      end

      def get_lists(list_path)
        verbose "Getting list names from #{list_path}"
        absolute_path = expand_list_path(list_path)
        list_files = Dir.foreach(absolute_path).select { |file|
          File.file?(File.expand_path(file, absolute_path))
        }.select { |file|
          File.readable?(File.expand_path(file, absolute_path))
        }
        list_files
      end
    end
  end
end
