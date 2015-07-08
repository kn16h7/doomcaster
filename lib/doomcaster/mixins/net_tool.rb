module DoomCaster
  require_relative '../common'
  module Tools
    class NetTool < DoomCaster::DoomCasterTool
      include DoomCaster::HttpUtils
    end
  end
end
