module Jurandir
  class String
    def bg_red
      self.colorize(:background => :red, :color => :white)
    end
  end
  
  module Modules
    class AdminFinder < Jurandir::JurandirModule
      def initialize(opts)
        super('admin-finder', opts)
      end

      def run
        @parser.parse!
        site = self.options[:host]
        lang = self.options[:lang]

        list_path = unless options[:list_path]
                      ENV['HOME'] + "/.jurandir.rb/lists"
                    else
                      options[:list_path]
                    end
        
        unless site
          print " Enter the website you want to scan \n".red.bold
          print" e.g.: www.domaine.com or www.domaine.com/path\n".red.bold
          print" --> ".red.bold
          site = gets.chomp
        end

        codes = get_langs(list_path)
        
        unless lang
          print "\n\n"
          print " Enter the coding language of the website \n".red.bold
          print " If you don't know the launguage used in the coding then simply type ** any ** \n".red.bold
          print " The available languages are:\n".red.bold

          codes.each_index { |idx|
            puts " [#{idx}] #{codes[idx]}".red.bold
          }

          loop do
            begin
              print " --> ".red.bold
              idx = Integer(gets.chomp)

              unless codes[idx]
                puts " Unknown language!".bg_red
              else
                lang = codes[idx]
                break
              end
            rescue ArgumentError
              puts " Invalid input!".bg_red
            end
          end
        end
        
        site = "http://" + site if site !~ /^http:/
        site = site + "/" if site !~ /\/$/
        
        print "\n->The website: #{site}\n".green
        print "->Source of the website: #{lang}\n".green
        print "->Scan of the admin control panel is progressing...\n\n\n".green
        search_generic(site, list_path + "/#{lang}_list")
      end

      def parse_opts(parser)
        @parser = parser

        @parser.separator ""
        @parser.separator "admin-finder tool specific options:\n"
        
        @parser.on("--host <host>", "The target host to be scanned") do |host|
          self.options[:host] = host
        end

        @parser.on("--lang <lang>", "The language of the host's back-end") do |lang|
          self.options[:lang] = lang
        end

        @parser.on("--list-path <path>", "The path where to look up for lists") do |path|
          self.options[:list_path] = path
        end

        @parser.on("--help", "Print this help message") do |opt|
          puts @parser
          exit          
        end
      end

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

      def search_generic(site, list_file)
        found = false
        
        File.open(list_file) do |f|
          f.each_line do |line|
            next if line =~ /^LANGUAGE:/
            
            complete_uri = site + line
            print "\n [*] Trying: #{complete_uri}".green.bold
            
            res = Net::HTTP.get_response(URI(complete_uri))
            
            if res.code =~ /404/
              print " [-] Not Found <- #{complete_uri}\n".red.bold;
              next
            elsif res.code =~ /302/
              location = res['Location']

              new_uri = if location =~ /^http:/
                          location
                        else
                          complete_uri.chomp + location
                        end
              
              print %Q{\n [*] Possible admin page found in: #{new_uri}. But jurandir will check!\n}.bold

              new_res =  Net::HTTP.get_response(URI(new_uri))
              
              if check_site(new_res)
                print "\n [+] Found -> #{new_uri}\n".green.bold
                print "\n [+] But this admin page is actually in another place\n".green.bold
                print "\n [+] Congratulation, this admin login page is working.\n\n Good luck from SuperSenpai.\n\n".green.bold
                found = true
              else
                print " [-] False positive: #{new_uri} is not a valid admin page.".bg_red
                next
              end
            elsif res.code =~ /200/ && check_site(res)
              print "\n [+] Found -> #{complete_uri}\n".green.bold
              print " [+] Congratulation, this admin login page is working.\n Good luck from SuperSenpai.\n".green.bold
              found = true
            else
              print " [-] Not Found <- #{complete_uri}\n".red
            end

            if found
              print " Desired page found. Do you want to continue?[s/n]: ".bold
              answer = gets.chomp
              
              if answer =~ /s/
                puts " Ok...".green.bold
              elsif answer =~ /n/
                puts " Ok!".green.bold
                break
              end          
            end
          end
        end
      end

      def get_langs(list_path)
        Dir.foreach(list_path).select { |entry|
          !File.directory?(entry)
        }.select { |entry|
          !File.readable?(entry)
        }.select { |file|
          File.open(list_path + '/' + file, "r").readline() =~ /LANGUAGE/
        }.collect { |file|
          File.open(list_path + '/' + file, "r").readline().split(" ")[1]
        }
      end

      def print_langs(list_path)
        get_langs(list_path).each { |lang| puts lang }
      end      
    end
  end
end
