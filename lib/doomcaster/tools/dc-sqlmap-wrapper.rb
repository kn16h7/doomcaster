module DoomCaster
  module Tools
    class SqlmapWrapper < NetTool      
      class BadConfiguredSwitchError < StandardError; end
      
      class SqlmapSwitch
        attr_reader :name, :attributes
        attr_accessor :value

        def initialize(attributes, name, value = nil)
          @name = name
          @value = value
          @attributes = attributes

          if @attributes.include?(:long) && @attributes.include?(:short)
            message = "A switch cannot be a long and short switch at the "
            message << "same time."
            raise ArgumentError, message
          end

          if @attributes.include?(:valueless) && @attributes.include?(:value_required)
            message = "A switch cannot be valueless and require a value at the same time"
            raise ArgumentError, message
          end
        end

        def to_s
          result = nil
          if @attributes.include?(:long)
            if @attributes.include?(:valueless)
              result = "--#{@name}"

              if @value
                message = "The switch #{@name} does not require an argument. "
                message << "The argument given to this switch will be ignored"
                verbose(message)
              end
            else
              raise BadConfiguredSwitchError, "The switch #{@name} requires an argument." \
                unless @value

              result = "--#{@name} '#{@value}'"
            end
          else
            result = "-#{@name} '#{@value}'"
          end
          result
        end

        def ==(another)
          @type == another.type &&
            @name == another.name &&
            @value == another.value &&
            @attribute == another.attribute
        end
      end

      #a map with the known switches sqlmap has as keys
      #to their attribute. This is useful to avoid that the
      #user specifies an argument to an option that does not
      #require a value, maintain a "database" of all possible
      #sqlmap options and also emit special warnings and
      #information on certain options.
      KNOWN_SWITCHES = {
                        "help" => [:valueless, :long],
                        "version" => [:valueless, :long],
                        "h" => [:valueless, :short],
                        "hh" => [:valueless, :short],
                        "v" => [:value_required, :short],
                        "u" => [:value_required, :short],
                        "d" => [:value_required, :short],
                        "l" => [:value_required, :short],
                        "x" => [:value_required, :short],
                        "m" => [:value_required, :short],
                        "r" => [:value_required, :short],
                        "g" => [:value_required, :short],
                        "c" => [:value_required, :short],
                        "url" => [:value_required, :long],
                        "method" => [:value_required, :long],
                        "data" => [:value_required, :long],
                        "param-del" => [:value_required, :long],
                        "cookie" => [:value_required, :long],
                        "cookie-del" => [:value_required, :long],
                        "load-cookies" => [:value_required, :long],
                        "drop-set-cookie" => [:value_required, :long],
                        "user-agent" => [:value_required, :long],
                        "random-agent" => [:value_required, :long],
                        "host" => [:value_required, :long],
                        "referer" => [:value_required, :long],
                        "headers" => [:value_required, :long],
                        "auth-type" => [:value_required, :long],
                        "auth-cred" => [:value_required, :long],
                        "auth-private" => [:value_required, :long],
                        "ignore-401" => [:value_required, :long],
                        "proxy" => [:value_required, :long],
                        "proxy-cred" => [:value_required, :long],
                        "proxy-file" => [:value_required, :long],
                        "ignore-proxy" => [:value_required, :long],
                        "tor" => [:valueless, :long],
                        "tor-port" => [:value_required, :long],
                        "tor-type" => [:value_required, :long],
                        "check-tor" => [:valueless, :long],
                        "delay" => [:value_required, :long],
                        "timeout" => [:value_required, :long],
                        "retries" => [:value_required, :long],
                        "randomize" => [:value_required, :long],
                        "safe-url" => [:value_required, :long],
                        "safe-freq" => [:value_required, :long],
                        "skip-urlencode" => [:valueless, :long],
                        "csrf-token" => [:value_required, :long],
                        "csfr-url" => [:value_required, :long],
                        "force-ssl" => [:valueless, :long],
                        "hpp" => [:valueless, :long],
                        "eval" => [:value_required, :long],
                        "o" => [:valueless, :short],
                        "predict-output" => [:valueless, :long],
                        "keep-alive" => [:valueless, :long],
                        "null-connection" => [:valueless, :long],
                        "threads" => [:value_required, :long],
                        "p" => [:value_required, :short],
                        "skip" => [:value_required, :long],
                        "dbms" => [:value_required, :long],
                        "dbms-cred" => [:value_required, :long],
                        "os" => [:value_required, :long],
                        "invalid-bignum" => [:valueless, :long],
                        "invalid-logical" => [:valueless, :long],
                        "invalid-string" => [:valueless, :long],
                        "no-cast" => [:valueless, :long],
                        "no-escape" => [:valueless, :long],
                        "prefix" => [:value_required, :long],
                        "suffix" => [:value_required, :long],
                        "tamper" => [:value_required, :long],
                        "level" => [:value_required, :long],
                        "risk" => [:value_required, :long],
                        "string" => [:value_required, :long],
                        "not-string" => [:value_required, :long],
                        "regexp" => [:value_required, :long],
                        "code" => [:value_required, :long],
                        "text-only" => [:valueless, :long],
                        "titles" => [:valueless, :long],
                        "technique" => [:value_required, :long],
                        "time-sec" => [:value_required, :long],
                        "union-cols" => [:value_required, :long],
                        "union-char" => [:value_required, :long],
                        "union-from" => [:value_required, :long],
                        "dns-domain" => [:value_required, :long],
                        "second-order" => [:value_required, :long],
                        "f" => [:valueless, :short],
                        "fingerprint" => [:valueless, :long],
                        "a"  => [:valueless, :short],
                        "all" => [:valueless, :long],
                        "b" => [:valueless,  :short],
                        "banner" => [:valueless, :long],
                        "current-user" => [:valueless, :long],
                        "current-db" => [:valueless, :long],
                        "hostname" => [:valueless, :long],
                        "is-dba" => [:valueless, :long],
                        "users" => [:valueless, :long],
                        "passwords" => [:valueless, :long],
                        "privileges" => [:valueless, :long],
                        "roles" => [:valueless, :long],
                        "dbs" => [:valueless, :long],
                        "tables" => [:valueless, :long],
                        "columns" => [:valueless, :long],
                        "schema" => [:valueless, :long],
                        "count" => [:valueless, :long],
                        "dump" => [:valueless, :long],
                        "dump-all" => [:valueless, :long],
                        "search" => [:valueless, :long],
                        "comments" => [:valueless, :long],
                        "D" => [:value_required, :short],
                        "T" => [:value_required, :short],
                        "C" => [:value_required, :short],
                        "X" => [:value_required, :short],
                        "U" => [:value_required, :short],
                        "exclude-sysdbs" => [:valueless, :long],
                        "where" => [:value_required, :long],
                        "start" => [:value_required, :long],
                        "stop" => [:value_required, :long],
                        "first" => [:value_required, :long],
                        "last" => [:value_required, :long],
                        "sql-query" => [:value_required, :long],
                        "sql-shell" => [:valueless, :long],
                        "sql-file" => [:value_required, :long],
                        "common-tables" => [:valueless, :long],
                        "common-columns" => [:valueless, :long],
                        "udf-inject" => [:valueless, :long],
                        "shared-lib" => [:value_required, :long],
                        "file-read" => [:value_required, :long],
                        "file-write" => [:value_required, :long],
                        "file-dest" => [:value_required, :long],
                        "os-cmd" => [:value_required, :long],
                        "os-shell" => [:valueless, :long],
                        "os-pwn" => [:valueless, :long],
                        "os-smbrelay" => [:valueless, :long],
                        "os-bof" => [:valueless, :long],
                        "priv-esc" => [:valueless, :long],
                        "msf-path" => [:value_required, :long],
                        "tmp-path" => [:value_required, :long],
                        "reg-read" => [:valueless, :long],
                        "reg-add" => [:valueless, :long],
                        "reg-del" => [:valueless, :long],
                        "reg-key" => [:value_required, :long],
                        "reg-value" => [:value_required, :long],
                        "reg-data" => [:value_required, :long],
                        "reg-type" => [:value_required, :long],
                        "s" => [:value_required, :short],
                        "t" =>[:value_required, :short],
                        "batch" => [:valueless, :long],
                        "charset" => [:value_required, :long],
                        "crawl" => [:value_required, :long],
                        "csv-del" => [:value_required, :long],
                        "dump-format" => [:value_required, :long],
                        "eta" => [:valueless, :long],
                        "flush-session" => [:valueless, :long],
                        "forms" => [:valueless, :long],
                        "fresh-queries" => [:valueless, :long],
                        "hex" => [:valueless, :long],
                        "output-dir" => [:value_required, :long],
                        "parse-errors" => [:valueless, :long],
                        "pivot-column" => [:value_required, :long],
                        "save" => [:valueless, :long],
                        "scope" => [:value_required, :long],
                        "test-filter" => [:value_required, :long],
                        "update" => [:valueless, :long],
                        "z" => [:value_required, :short],
                        "alert" => [:value_required, :long],
                        "answers" => [:value_required, :long],
                        "beep" => [:valueless, :long],
                        "cleanup" => [:valueless, :long],
                        "dependencies" => [:valueless, :long],
                        "disable-coloring" => [:valueless, :long],
                        "gpage" => [:value_required, :long],
                        "identify-waf" => [:valueless, :long],
                        "mobile" => [:valueless, :long],
                        "page-rank" => [:valueless, :long],
                        "purge-output" => [:valueless, :long],
                        "smart" => [:valueless, :long],
                        "sqlmap-shell" => [:valueless, :long],
                        "wizard" => [:valueless, :long]
                       }

      def SqlmapWrapper.load_scan_file(name)
        scan_file_home = if @options[:scan_file_path]
                           @options[:scan_file_path]
                         else
                           File.expand_path('/wordlists/sqlmap-wrapper-scans', ENV['DOOMCASTER_HOME'])
                         end
        verbose "The path where this tool will look up for files is #{scan_file_home}"

        if Dir.foreach(scan_file_home).include?(name)
          switches = []
          file_scans_path = File.expand_path(name, scan_file_home)
          File.open(file_scans_path).each_line do |line|
            option, value = line.split(" ")

            unless KNOWN_SWITCHES.key?(option)
              verbose "The switch #{option} is unknown and is going to be ignored"
              next
            else
              attributes = KNOWN_SWITCHES[option]

              switch = nil
              if attributes.include?(:value_required)
                switch = SqlmapSwitch.new(attributes, option, value)
              else
                switch = SqlmapSwitch.new(attributes, option)
              end

              verbose "Loaded switch #{switch} from file #{file_scans_path}"
              switches << switch
            end
          end
          switches
        else
          nil
        end
      end
      
      def initialize
        super("dc-sqlmap-wrapper", {})
      end

      def desc
        DoomCaster::ToolDesc.new(
                                 "A simple wrapper around sqlmap",
                                 %Q{
This tool is a simple wrapper to run sqlmap. It's meant to simplify its use
avoiding the need of repeat a lot of very used switches using "scan files".
A scan file is a simple list with a sqlmap swich (without the dashes) and its
arguments. If you want that a argument to be overwritable in the command line
(with the option "--switches", to overwrite the "(undefined)" value).

Examples:
This is the content of the file "basic-scan":

url (undefined)
dbs
level 2
risk 2

The "url" switch must be set up in the command line of DoomCaster, with the
option "--switches". The above scan file would require the command line:

doomcaster --tool 'dc-sqlmap-wrapper' --scan-file 'basic-scan' --swiches 'url http://www.vuln.com/index.php?id=666'

And would yield the following sqlmap command:

sqlmap --url 'http://www.vuln.com/index.php?id=666' --dbs --level 2 --risk 2

If you typed:

doomcaster --tool 'dc-sqlmap-wrapper' --scan-file 'basic-scan'

It would give an error saying that you need to overwrite the switch "--url" with
a value.

You can create your own scan files to generalize repetitive commands inside:
$DOOMCASTER_HOME/sqlmap-wrapper-scans

For example: A scan file called "dump-all" with the following content:

url (undefined)
dbs
banner
level 3
risk 2
dump-all

It would be useful in a scan to dump everything.
                                 })
      end

      def before_run
        set_sqlmap_cmd
        #print banner
        
        if @options[:scan_file]
          scan_file = SqlmapWrapper.load_scan_file(@options[:scan_file])

          "Scan file not found: #{@options[:scan_file]}" unless scan_file

          @switch_set = scan_file
          set_switches(@options[:switches], @switch_set)
        elsif @options[:switches]
          @switch_set = []
          set_switches(@options[:switches], @switch_set)
        else
          message = "Lacking a scan type or a set of switches. Specify a scan type "
          message << "with --scan-file or pass the switches directly to sqlmap with "
          message << "--switches."
          fail_exec message
        end

        begin
          analize_options(@switch_set)
        rescue BadConfiguredSwitchError => e
          fail_exec e.message
        end
      end

      def do_run_tool
        run_sqlmap()
      end

      def parse_opts(parser, args = ARGV)
        @parser = parser

        args.map! do |arg|
          if arg =~ /^--/
            arg
          end

          String.remove_quotes_if_has_quotes(arg)
        end
        
        @parser.separator ""
        @parser.separator "dc-sqlmap-wrapper specific options:"

        super(@parser)

        @parser.on("--scan-file <type>", "The scan file to be used") do |scan|
          @options[:scan_file] = scan
        end

        @parser.on("--scan-file-path <path>", "The path where DoomCaster will look up for scan files") do |path|
          @options[:scan_file_path]
        end

        @parser.on("--sqlmap-path <path>", "The path where sqlmap is installed") do |path|
          @options[:sqlmap_path] = path
        end

        @parser.on("--switches <switches>", "Give switches directly to sqlmap. This option \
                   also switches switches defined in a scan file") do |overs|
          @options[:switches] = overs
        end

        @parser.on("--inherit-proxy", "Make sqlmap inherit proxy options in DoomCaster") do |inherit|
          @options[:inherit_proxy] = inherit
        end

        @parser.on("--manual", "Display a detailed manual") do
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
      def run_sqlmap
        args = switch_arr_to_cmd(@switch_set)
        verbose "sqlmap will run. The complete command line is: #{@sqlmap_cmd} #{args}"
        info "Running sqlmap..."
        system("#{@sqlmap_cmd} #{args}")
      end

      def analize_options(switch_set)
        handles = {
                   "h" => lambda {
                     message = "Warning: The swtich -h is useless here use and will"
                     message << " cause sqlmap to just display a help message and exit."
                     warn message
                   },
                   "hh" => lambda {
                     message = "Warning: The swtich -hh is useless here and will cause"
                     message << " sqlmap to just display a help message and exit."
                     warn message
                   },
                   "g" => lambda {
                     message "Why are you using the sqlmap dorker? DoomCaster has a tool "
                     message "called dcdorker to automatize dorking."
                     warn message
                   },
                   "version" => lambda {
                     message = "Warning: The switch --version is useless here and will cause"
                     messsage << " sqlmap to display a version message and exit."
                     warn message
                   }
                  }
        
        switch_set.each do |switch|
          handle = handles[switch.name]
          handle.call if handle
        end

        switch_set.each do |switch|
          if switch.value == "(undefined)"
            message = "The switch --#{switch.name} has an undefined value and requires"
            message << " that a value to be given through command line. Please, provide"
            message << " a value for this switch with the option --switch."
            raise BadConfiguredSwitchError, message
          end
        end
      end
      
      def switch_arr_to_cmd(switch_arr)
        switch_arr.map! { |switch| switch.to_s }.join(" ")
      end

      def set_sqlmap_cmd
        system('type sqlmap')
        if $?.exitstatus == 1
          unless @options[:sqlmap_path]
            message = "Cannot run dc-sqlmap-hook: sqlmap is not installed. "
            message << "Please install sqlmap or specify the directory where sqlmap.py is "
            message << "installed with the option \"--sqlmap-path <path>\" (in case that "
            message << "sqlmap is installed in a custom directory)."
            fail_exec message
          else
            sqlmap_path = File.expand_path(@options[:sqlmap_path])
            
            verbose "Possible sqlmap path is #{sqlmap_path}"

            unless File.exists?(sqlmap_path)
              message = "The path you specified as sqlmap path does not "
              message << "exist.\n"
              message << "TIP: Remember that if the path is not absolute, DoomCaster "
              message << "will use the current path as reference to build the complete "
              message << "path."
              fail_exec message
            end

            unless File.directory?(sqlmap_path)
              message = "The path you specified as sqlmap path is not a "
              message << "directory."
              fail_exec message
            end

            unless Dir.foreach(sqlmap_path).include?('sqlmap.py')
              message = "sqlmap.py does not exist inside the directory "
              message << "you specified as sqlmap path."
              fail_exec message
            end

            system('type python')
            if $?.exitstatus == 1
              message = " [^] WHAT? sqlmap is installed but Python is not! "
              message << "Please install Python or you won't even be able to use "
              message << "sqlmap. :^)"
              if $execution_mode == :once
                homossexual message
              else
                die message.pink
              end
            end

            @sqlmap_cmd = "python #{sqlmap_path}/sqlmap.py"
          end
        else
          @sqlmap_cmd = "sqlmap"
        end
        verbose "Obtained command to run sqlmap is #{@sqlmap_cmd}"
      end

      def set_switches(switches, switch_set)
        return unless switches
        arg_names = switch_set.map { |switch| switch.name }

        switch_parts = switches.split(" ")
        processed = 0
        switch_idx = 0
        value_idx = 1
        
        until processed == switch_parts.length
          switch_name = switch_parts[switch_idx]
          
          if KNOWN_SWITCHES.key?(switch_name)
            attrs = KNOWN_SWITCHES[switch_name]

            if attrs.include?(:value_required)
              switch_val = switch_parts[value_idx]

              if arg_names.include?(switch_name)
                switch_set.each do |switch|
                  if switch.name == switch_name
                    message = "Overwriting switch #{switch_name} with the new "
                    message << "value #{switch_val}"
                    verbose message
                    switch.value = switch_val
                  else
                    next
                  end
                end
              else
                verbose "Adding new switch #{switch_name} previously not given"
                switch_set << SqlmapSwitch.new(attrs, switch_name, switch_val)
              end

              switch_idx += 2
              value_idx += 2
              processed += 2
            else
              if arg_names.include?(switch_name)
                message = "Switch #{switch_name} is already included in scan type "
                message << "and will be ignored"
                verbose message
              else
                message = "Adding new switch #{switch_name} previously not given"
                switch_set << SqlmapSwitch.new(attrs, switch_name)
                verbose message
              end
              switch_idx += 1
              value_idx += 1
              processed += 1
            end
          else
            message = "The provided switch --#{switch_name} is "
            message << "unknown and is going to be ignored."
            verbose message
            switch_idx += 1
            value_idx += 1
            processed += 1
          end
        end

        if @options[:inherit_proxy]
          unless @proxy
            message = '"--inherit-proxy" given but no proxy was set. This option '
            message << 'will be ignored'
            verbose message
            return
          else
            verbose "Extending sqlmap command line to inherit DoomCaster proxy"
            proxy_switch = nil
            proxy_info = SqlmapSwitch(KNOWN_SWITCHES["proxy"], "proxy",
                                      "http://#{@proxy.addr}:#{@proxy.port}")
            if @proxy.name || @proxy.password
              proxy_cred = SqlmapSwitch(KNOWN_SWITCHES["proxy-cred"], "proxy-cred",
                                        "#{@proxy.name}:#{@proxy.password}")
              proxy_switch = [proxy_info, proxy_cred]
            else
              proxy_switch = proxy_info
            end
            switch_set << proxy_switch
          end
        end
      end
    end
  end
end
