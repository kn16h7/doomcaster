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
        code = self.options[:code]

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

        codes = Jurandir::get_langs(list_path)
        
        unless code
          print "\n\n"
          print " Enter the coding language of the website \n".red.bold
          print " If you don't know the launguage used in the coding then simply type ** any ** \n".red.bold
          print " The available languages are:\n".red.bold

          codes.each_index { |idx|
            puts "[#{idx}] #{codes[idx]}".red.bold
          }

          loop do
            begin
              print " --> ".red.bold
              code = Integer(gets.chomp)

              unless codes[code]
                puts "Unknown language!".bg_red
              else
                break
              end
            rescue ArgumentError
              puts "Invalid input!".bg_red
            end
          end
        end
        
        site = "http://" + site if site !~ /^http:/
        site = site + "/" if site !~ /\/$/
        
        print "\n->The website: #{site}\n".green
        print "->Source of the website: #{code}\n".green
        print "->Scan of the admin control panel is progressing...\n\n\n".green
        Jurandir::search_generic(site, list_path + "/#{codes[code]}_list")
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
          self.options[:list_path]
        end

        @parser.on("--help", "Print this help message") do |opt|
          puts @parser
          exit          
        end
      end

      def Jurandir.search_generic(site, list_file)
        found = false
        
        File.open(list_file) do |f|
          f.each_line do |line|
            next if line =~ /LANGUAGE:/
            
            complete_uri = site + line
            print "[*] Trying: #{complete_uri}".green.bold
            
            res = Net::HTTP.get_response(URI(complete_uri))

            if res.code =~ /404/
              print "[-] Not Found <- #{complete_uri}\n".red.bold;
            elsif res.code =~ /302/
              location = complete_uri.chomp + res['Location']
              
              print " \n [+] Found -> #{location}\n".green.bold;
              print " \n [+] But this admin page is actually in another place \n".green.bold
              print " \n Congratulation, this admin login page is working. \n Good luck from SuperSenpai \n\n".green.bold
              found = true
            elsif res.body =~ /Username/ ||
                res.body =~ /Password/ ||
                res.body =~ /username/ ||
                res.body =~ /password/ ||
                res.body =~ /USERNAME/ ||
                res.body =~ /PASSWORD/ ||
                res.body =~ /Senha/ ||
                res.body =~ /senha/ ||
                res.body =~ /Personal/ ||
                res.body =~ /Usuario/ ||
                res.body =~ /Clave/ ||
                res.body =~ /Usager/ ||
                res.body =~ /usager/ ||
                res.body =~ /Sing/ ||
                res.body =~ /passe/ ||
                res.body =~ /P\/W/ ||
                res.body =~ /Admin Password/
              print " \n [+] Found -> #{complete_uri}\n\n".green.bold
              print " \n Congratulation, this admin login page is working. \n Good luck from SuperSenpai \n".green.bold
              found = true
            else
              print "[-] Not Found <- #{complete_uri}\n".red
            end

            if found
              print "Desired page found. Do you want to continue?[s/n]: ".green.bold
              answer = gets.chomp
              
              if answer =~ /s/
                puts "Ok...".green.bold
              elsif answer =~ /n/
                puts "Ok!".green.bold
                break
              end          
            end
          end
        end
      end

      def Jurandir.get_langs(list_path)
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

      def Jurandir.print_langs(list_path)
        get_langs(list_path).each { |lang| puts lang }
      end
    end
  end
end
