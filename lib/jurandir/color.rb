require 'colorize'

class String
  def bg_red
    self.colorize(:background => :red, :color => :white)
  end
end
