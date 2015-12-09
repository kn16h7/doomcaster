module DoomCaster
  module HttpUtils
    require 'net/http'
    require 'socksify/http'

    class ProxyInfo
      attr_reader :addr, :port, :type, :name, :password

      def initialize(type, addr, port, name = nil, pass = nil)
        @type = type
        @addr = addr
        @port = port
        @name = name
        @password = pass
      end
    end

    def build_get_req(uri, headers)
      if uri.path && uri.query
        Net::HTTP::Get.new(uri.path + '?' + uri.query, headers)
      elsif uri.path
        Net::HTTP::Get.new(uri.path, headers)
      else
        Net::HTTP.Get.new('/', headers)
      end
    end
    
    def do_http_get(uri, headers = nil, proxy_info = nil, opts = {})
      uri = URI.parse(URI.escape(uri)) unless uri.is_a?(URI)

      opts[:use_ssl] = true if uri.scheme == 'https'

      if proxy_info
        if proxy_info.type == 'HTTP'
          if proxy_info.name || proxy_info.password
            Net::HTTP.start(uri.host, uri.port, proxy_info.addr, proxy_info.port,
                            proxy_info.name, proxy_info.password, opts) do |http|
              return http.request(build_get_req(uri, headers))
            end
          else
            Net::HTTP.start(uri.host, uri.port, proxy_info.addr, proxy_info.port, opts) do |http|
              return http.request(build_get_req(uri, headers))
            end
          end
        elsif proxy_info.type == 'SOCKS'
          Net::HTTP.SOCKSProxy(proxy_info.addr, proxy_info.port).start(uri.host, uri.port, opts) do |http|
            return http.request(build_get_req(uri, headers))
          end
        else
          raise ArgumentError, 'Unknown proxy type'
        end
      else
        Net::HTTP.start(uri.host, uri.port, opts) do |http|
          return http.request(build_get_req(uri, headers))
        end
      end
    end
  end
end
