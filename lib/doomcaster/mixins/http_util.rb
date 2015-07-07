module DoomCaster
  module HttpUtils
    require 'net/http'
    
    def do_http_get(uri, timeout = 60)
      http_handle = if uri.is_a?(URI)
                      Net::HTTP.new(uri.host, uri.port)
                    else
                      str_uri = URI.parse(URI.escape(uri))
                      Net::HTTP.new(str_uri.host, str_uri.port)
                    end
      
      http_handle.read_timeout = timeout
      req = Net::HTTP::Get.new(uri.path + '?' + uri.query)
      http_res = http_handle.request(req)
      http_res
    end
  end
end
