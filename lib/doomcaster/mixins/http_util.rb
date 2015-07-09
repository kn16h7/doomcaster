module DoomCaster
  module HttpUtils
    require 'net/http'
    require 'socksify/http'

    class ProxyInfo
      attr_reader :addr, :port, :type

      def initialize(type, addr, port)
        @type = type
        @addr = addr
        @port = port
      end
    end

    def build_get_req(uri)
      if uri.path && uri.query
        Net::HTTP::Get.new(uri.path + '?' + uri.query)
      elsif uri.path
        Net::HTTP::Get.new(uri.path)
      else
        Net::HTTP.Get.new('/')
      end
    end
    
    def do_http_get(uri, proxy_info = nil)
      uri = URI.parse(URI.escape(uri)) unless uri.is_a?(URI)

      if proxy_info
        if proxy_info.type == 'HTTP'
          Net::HTTP.start(uri.host, uri.port, proxy_info.addr, proxy_info.port) do |http|          
            return http.request(build_get_req(uri))
          end
        elsif proxy_info.type == 'SOCKS'
          Net::HTTP.SOCKSProxy(proxy_info.addr, proxy_info.port).start(uri.host, uri.port) do |http|
            return http.request(build_get_req(uri))
          end
        else
          raise ArgumentError, 'Unknown proxy type'
        end
      else
        Net::HTTP.start(uri.host, uri.port) do |http|
          return http.request(build_get_req(uri))
        end
      end
    end
  end
end
