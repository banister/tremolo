begin
  # In case you use Gosu via RubyGems.
  require 'rubygems'
rescue LoadError
  # In case you don't.
end

require 'gosu'
require 'controllers'
require 'actors'
require 'player'
require 'environ'
require 'common'

#Manages the game
class GameController
   def initialize(window)
     @window = window
     @jukebox = MusicSystem.new(@window)
     @anims = ImageSystem.new(@window)
     @world = Array.new    
     @phys = PhysicsController.new
     @env = EnvironmentController.new(@window)        
     
     @player1 = nil
     @player2 = nil
     
     
     setup_interface
     setup_tanks
     setup_players   
     setup_world

     puts "starting game."     
   end
   
   def setup_interface
    puts "setting up interface..."
    #setting up font, and background
    @font = Gosu::Font.new(@window, Gosu::default_font_name, 20)
    
    #setting up mouse
    @mouse = MousePtr.new(@window,@world,@env)
     
    #setting up game music
    playlist = [@jukebox.load_song("assets/bouncelong.ogg"),@jukebox.load_song("assets/loop.ogg")]
    @jukebox.make_play_list(:soundtrack,playlist)
    @jukebox.load_play_list(:soundtrack)    
    @jukebox.loop = true
    
    puts "...done!"
   end
  
   def setup_world
    puts "setting up game world..."    
    
    #sample actors
    num_sa = 10
    
    #physors
    num_phys = 5
    
    puts "creating #{num_sa} SampleActors..."
    (1..num_sa).each  { @world.push(SampleActor.new(@window))  }
    
    (1..5).each { @world.push(Digger.new(@window, rand(2924), rand(500), 0, 0, @world, @phys, @env)) }
   
   
    
    num_phys.times do
      mag = rand(40)-20
      @world.push(Physor.new(@phys,mag,@window))
      puts "creating Physor of mag #{mag}..."
    end
    
    puts "randomizing positions of game actors..."
    @world.each { |thing| thing.warp(rand(2924),rand(500)) }  
    
     # create an Andy
    @world.push(Andy.new(@window, 110, 515, 0, 0, @world, @phys, @env))
     
    #bring players into the world   
    @world.push(@player1)
    #@world.push(@player2)
    
    #setting up environment
    @env.load_env("desert1")
    
    puts "...done!"    
   end
   
   def setup_tanks
    #common to both players
    effects=EffectsSystem.new(@window)
    effects.add_effect(:tankexplode,"assets/tankexplode.wav")
    effects.add_effect(:tankshot,"assets/tankshot.wav")
    effects.add_effect(:puff,"assets/puff.wav")
    effects.add_effect(:turret,"assets/turret.wav")
    effects.add_effect(:bullet,"assets/bullet.wav")
    
    #leopard
    leopard = Tank.new    
    p_anims = ImageSystem.new(@window)
    p_anims.make_animation(:standard,p_anims.load_image("assets/rtank.png"),1,false)
    p_anims.make_animation(:aliveblast,p_anims.load_frames("assets/leopardshot.png",77,32),0.06,false)
    p_anims.make_animation(:deadblast,p_anims.load_frames("assets/blast2.png",77,32),0.06,false)
    p_anims.make_animation(:burnedtank,p_anims.load_image("assets/tankburned.png"),1,false)           
    leopard.anims = p_anims
    leopard.effects = effects
    leopard.turret.x = 24
    leopard.turret.y = -7
    leopard.turret.length = 38
    leopard.turret.anims = ImageSystem.new(@window)
    leopard.turret.anims.make_animation(:standard,leopard.turret.anims.load_image("assets/turret.png"),1,false)
    leopard.turret.anims.make_animation(:fire,leopard.turret.anims.load_frames("assets/canblast.png",40,27),0.06,false)
        
            
    #japanese tank
    japan = Tank.new    
    p_anims = ImageSystem.new(@window)
    p_anims.make_animation(:standard,p_anims.load_image("assets/gtank.png"),1,false)
    p_anims.make_animation(:aliveblast,p_anims.load_frames("assets/leopardshot.png",77,32),0.06,false)
    p_anims.make_animation(:deadblast,p_anims.load_frames("assets/blast2.png",77,32),0.06,false)    
    p_anims.make_animation(:burnedtank,p_anims.load_image("assets/tankburned.png"),1,false)       
    japan.anims = p_anims
    japan.effects = effects
    japan.turret.x = 28
    japan.turret.y = 0
    japan.turret.length = 38
    japan.turret.anims = ImageSystem.new(@window)
    japan.turret.anims.make_animation(:standard,japan.turret.anims.load_image("assets/turret.png"),1,false)        
    japan.turret.anims.make_animation(:fire,japan.turret.anims.load_frames("assets/canblast.png",40,27),0.06,false)
    
    #instantiate players
    @player1 = Player.new(@window, @world, leopard,@phys,@env)
    @player2 = Player.new(@window, @world, japan,@phys,@env,-1)   #-1 for facing the opposite direction
   end
   
   def setup_players
    @player1.controls = {:right => Gosu::KbD, :left => Gosu::KbA,
                       :vel_incr => Gosu::KbW, :vel_decr => Gosu::KbS,
                       :shoot_button => Gosu::Button::KbSpace}  
    @player1.warp(110, 515) 
        
    
    @player2.controls = {:right => Gosu::Button::KbRight, :left => Gosu::Button::KbLeft,
                       :vel_incr => Gosu::Button::KbUp, :vel_decr => Gosu::Button::KbDown,
                       :shoot_button => Gosu::Button::KbEnter}
    @player2.warp(1980,464)     
  end
  
  def update
    #update music
    @jukebox.update  
    
    #update mouse & scrolling (mouse is responsible for scrolling)
    @mouse.update
    
    #update actors    
    @world.each { |thing|  thing.update if (!thing.idle && !thing.expired) }    
    @world.delete_if { |thing| thing.expired }
  end
  
  def draw    
    #update scrolling info from mouse
    screen_x,screen_y=@mouse.screen_x,@mouse.screen_y
    
    @env.draw(screen_x,screen_y)   
    @world.each { |thing|  thing.draw(screen_x,screen_y) }  
    
    @mouse.draw 
    
    @font.draw("Player 1: Angle: #{360-@player1.angle}   Velocity: #{@player1.velocity}    Health: #{@player1.health}"+" "*48+
                "Player 2: Angle: #{@player2.angle}   Velocity: #{@player2.velocity}    Health: #{@player2.health}" , 10, 10, 3, 1.0, 1.0, 0xffffff00)
  end
  
  def button_down(id)    
    @player1.button_down(id)     
    @player2.button_down(id)
    @mouse.button_down(id)
  end
  
end
