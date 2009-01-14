!
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

require 'ruby-prof'

RubyProf.start

#Entry point
class MyWindow < Gosu::Window
    def initialize
        super(Common::SCREEN_X, Common::SCREEN_Y, false)
        self.caption = 'Tremolo'
        init_keyboard_constants
        @game = GameController.new(self)  

        @frame_counter = FPSCounter.new
        @font = Gosu::Font.new(self, Gosu::default_font_name, 20)
    end
    
    def update
        @game.update
        @frame_counter.register_tick
    end
    
    def button_down(id)    
        @game.button_down(id)
        if id == Gosu::KbEscape then
            result = RubyProf.stop

            # Print a flat profile to text
            printer = RubyProf::FlatPrinter.new(result)
            printer.print(STDOUT, 0)

            exit
        end
    end   
    
    def draw      
        @game.draw

        @font.draw("FPS: #{@frame_counter.fps}" ,
                   10, 10, 3, 1.0, 1.0, 0xffffff00)
    end
    
    def init_keyboard_constants()
        ('a'..'z').each do |letter|
            eval "Gosu::Kb#{letter.upcase} = #{self.char_to_button_id(letter)}"
        end
    end

end


w = MyWindow.new
w.show
