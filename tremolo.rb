# John Mair 2008
# Tremolo

begin
  # In case you use Gosu via RubyGems.
  require 'rubygems'
rescue LoadError
  # In case you don't.
end

require 'gosu'
require 'gamecontrol'

#Entry point
class MyWindow < Gosu::Window
  def initialize
    super(Common::SCREEN_X, Common::SCREEN_Y, false)
    self.caption = 'Tremolo'
    init_keyboard_constants
    @game = GameController.new(self)   
  end
   
  def update
    @game.update         
   end
   
   def button_down(id)    
    @game.button_down(id)     
   end   
      
  def draw      
    @game.draw
  end
  
  def init_keyboard_constants()
    ('a'..'z').each do |letter|
      eval "Gosu::Kb#{letter.upcase} = #{self.char_to_button_id(letter)}"
    end
  end

end

w = MyWindow.new
w.show

