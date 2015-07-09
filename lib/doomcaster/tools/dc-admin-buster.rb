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
                                 %q{A tool for find the administrative page in websites.
                                 }, %Q{
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
        @parser.parse!
        site = self.options[:host]
        list = self.options[:list]

        list_path = unless self.options[:list_path]
                      ENV['HOME'] + "/.doomcaster/wordlists/admin-lists"
                     else
                      self.options[:list_path]
                    end
        
        self.options[:list_path] = list_path || self.options[:list_path]
        lists = get_lists(list_path)
        
        unless site
          message = "Enter the website you want to scan "
          message <<  "(e.g.: www.domaine.com or www.domaine.com/path\):"
          site = ask_no_question message
        end
        
        unless list
          if lists.empty?
            fatal "Cannot scan site: No list available"
            exit 1
          end
          
          print "\n"
          info "Enter the list you want to use."
          info "The available lists are:\n"

          lists.each_index { |idx|
            puts " [#{idx}] #{lists[idx]}".red.bold
          }

          loop do
            begin
              print "==> ".red.bold
              idx = Integer(gets.chomp)

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
        else
          unless lists.include?(self.options[:list])
            fatal "Cannot scan site: The list you have specified with --list is unknown."
            return
          end
        end
        
        site = "http://" + site if site !~ /^http:/
        site = site + "/" if site !~ /\/$/

        puts "\n"
        info "The website: #{site}"
        info "List to be used: #{list}"
        info "Scan of the admin control panel is progressing...\n"
        search_generic(site, list)
      end

      def parse_opts(parser)
        @parser = parser

        @parser.separator ""
        @parser.separator "admin-finder options:\n"

        super(@parser)
        @parser.on("--host <host>", "The target host to be scanned") do |host|
          self.options[:host] = host
        end

        @parser.on("--list <list>", "The list to be used") do |list|
          self.options[:list] = list
        end

        @parser.on("--list-path <path>", "The path where to look up for lists") do |path|
          self.options[:list_path] = path
        end

        @parser.on("--help", "Print this help message") do
          puts @parser
          exit
        end

        @parser.on("--manual", "Print a detailed help message") do
          puts self.desc.detailed
          exit
        end
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

        list_file = nil
        Dir.foreach(self.options[:list_path]).select { |entry|
          !File.directory?(entry)
        }.select { |entry|
          !File.readable?(entry)
        }.select { |file|
          file = File.open(self.options[:list_path] + '/' + file, "r")
          begin
            file.readline =~ /NAME:/
          ensure
            file.close
          end
        }.collect { |file|
          file = File.open(self.options[:list_path] + '/' + file, "r")
          begin
            name = file.readline.split(" ").drop(1).join(' ')
            if name == list_file_name
              list_file = self.options[:list_path] + '/' + File.basename(file)
              break
            end
          ensure
            file.close
          end
        }

        
        File.open(list_file) do |f|
          f.each_line do |line|
            next if line =~ /^NAME:/
            
            complete_uri = site + line.chomp
            normal_info "Trying: #{complete_uri}"

            res = nil
            begin
              Timeout::timeout(60) do
                res = if @proxy
                        do_http_get(complete_uri, @proxy)
                      else
                        do_http_get(complete_uri)
                      end
              end
            rescue Timeout::Error
              fatal "Request timed out"
              next
            end
            
            if res.code =~ /404/
              bad_info "Not Found <- #{complete_uri}"
              next
            elsif res.code =~ /301/ || res.code =~ /302/
              location = res['Location']

              new_uri = if location =~ /^http:/
                          location
                        else
                          complete_uri.chomp + location
                        end
              
              normal_info "Possible admin page found in: #{new_uri}. But jurandir will check!"
              new_res =  Net::HTTP.get_response(URI(new_uri))
              
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
            elsif res.code =~ /200/ && check_site(res)
              good "Found -> #{complete_uri}\n"
              good "Congratulation, this admin login page is working.\n"
              good "Good luck from SuperSenpai.\n"
              found = true
            else
              bad_info "Not Found <- #{complete_uri}"
            end

            if found
              warn "WARNING: I recommend you to check if the page is really what you want before!"

              ask "Desired page found. Do you want to continue? [y/n]: " do |answer|
                if answer =~ /y/
                  puts "Ok...".green.bold
                  found = false
                elsif answer =~ /n/
                  puts "Ok!".green.bold
                  return
                else
                  bad_info "Invalid answer! DoomCaster will consider this as a no."
                  return
                end                
              end
            end
          end
        end
      end

      def get_lists(list_path)
        Dir.foreach(list_path).select { |entry|
          !File.directory?(entry)
        }.select { |entry|
          !File.readable?(entry)
        }.select { |file|
          file = File.open(list_path + '/' + file, "r")
          begin
            file.readline =~ /NAME:/
          ensure
            file.close
          end
        }.collect { |file|
          file = File.open(list_path + '/' + file, "r")
          begin
            file.readline.split(" ").drop(1).join(' ')
          rescue
          ensure
            file.close
          end
        }
      end
    end
  end
end
