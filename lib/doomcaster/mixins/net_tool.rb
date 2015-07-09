module DoomCaster
  require_relative '../common'
  module Tools
    class NetTool < DoomCaster::DoomCasterTool
      include DoomCaster::HttpUtils

      def initialize(name, opts = {}, proxy = nil)
        super(name, opts)
        @proxy = proxy
      end

      def parse_opts(parser)
        @parser = parser
        
        @parser.on("--proxy <type:address:port>", "Set a proxy") do |proxy|
          type, addr, port = proxy.split(":")
          @proxy = ProxyInfo.new(type, addr, port)
        end
      end
    end
  end
end
