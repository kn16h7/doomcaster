module DoomCaster
  module Tools
    class AdminFinder < NetTool
      require 'timeout'
      
      def initialize
        super('dc-admin-buster', {})
      end

      public
      def desc
        DoomCaster::ToolDesc.new(
                                 %q{A tool for find the administrative page in websites},
                                 %Q{
This tool try to find the admin page of an website by brute force, based on a
list and in some previous conditions. This tool will ask you for a site and an
list for select a list and start.

You can create your own list of possible admin pages. For this, go to:
/home/<your-home>/.doomcaster.rb/wordlists/admin-lists and inside this directory
create a new file where the first line MUST be:

NAME: name of your list
...

Then just fill the file with the possible pages, one per line.
                                 })
      end
      
      def run
        site = @options[:host]
        list = @options[:list]

        list_path = unless @options[:list_path]
                      @options[:list_path] = File.expand_path('wordlists/admin-lists', ENV['DOOMCASTER_HOME'])
                      @options[:list_path]
                    else
                      @options[:list_path]
                    end
        
        lists = get_lists(list_path)
        fail_exec self.name, "Cannot scan site: No list available" if lists.empty?

        if @options[:list]
          unless lists.include?(@options[:list])
            fail_exec "Cannot scan site: The list you have specified with --list is unknown"
          end
        end

        system('clear')
        Arts::dc_admin_buster_banner
        
        unless site
          message = "Enter the website you want to scan "
          message <<  "(e.g.: www.domaine.com or www.domaine.com/path\):"
          site = ask_no_question message
        end
        
        unless list
          print "\n"
          info "Enter the list you want to use."
          info "The available lists are:\n"

          lists.each_index { |idx|
            puts " [#{idx}] #{lists[idx]}".red.bold
          }

          loop do
            idx = read_num_from_user()
            unless lists[idx]
              puts " Unknown list!".bg_red
            else
              list = lists[idx]
              break
            end
          end
        end

        begin
          site = URI.parse(site)
        rescue URI::InvalidURIError
          fail_exec "Cannot scan: #{site} is not a valid URL."
        end

        if site.scheme
          if site.scheme != 'http' && site.scheme != 'https'
            fail_exec "Cannot scan: URI does not point to a site"
          end
        else
          site.scheme = 'http'
        end

        puts "\n"
        info "The website: #{site}"
        info "List to be used: #{list}"
        info "Scan of the admin control panel is progressing...\n"
        search_generic(site, list)
      end

      def parse_opts(parser, args = ARGV)
        @parser = parser

        @parser.separator ""
        @parser.separator "admin-finder options:\n"

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
          f.each_line do |line|
            next if line =~ /^NAME:/
            
            line = line.chomp
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
              Timeout::timeout(60) do
                res = do_http_get(try_uri, nil, @proxy)
              end
            rescue Timeout::Error
              fatal "Request timed out"
              next
            rescue SocketError
              fatal "Network error while attempting"
              next
            end
            
            if res.code =~ /404/
              bad_info "Not Found <- #{try_uri}"
              next
            elsif res.code =~ /301/ || res.code =~ /302/
              location = res['Location']

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
              new_res = do_http_get(new_uri, nil, @proxy)
              
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
