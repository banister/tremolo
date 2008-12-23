begin
    require 'rubygems'
rescue LoadError
end

require 'gosu'
require 'controllers'
require 'actors'
require 'tanks'
require 'environ'
require 'common'

# Manages the game
class GameController
    def initialize(window)
        @window = window
        @jukebox = MusicSystem.new(@window)
        @anims = ImageSystem.new(@window)
        @world = Array.new
        @phys = PhysicsController.new
        @env = EnvironmentController.new(@window)
        @ec = EventController.new

        setup_interface
        setup_world

        puts "starting game."
    end

    def setup_interface
        puts "setting up interface..."
        #setting up font, and background
        @font = Gosu::Font.new(@window, Gosu::default_font_name, 20)

        #setting up mouse
        @mouse = MousePtr.new(@window, @world, @env)
        @ec.register_listener(:button_down, @mouse)
       

        #setting up game music
        playlist = [@jukebox.load_song("assets/bouncelong.ogg"), @jukebox.load_song("assets/loop.ogg")]
        @jukebox.make_play_list(:soundtrack, playlist)
        @jukebox.load_play_list(:soundtrack)
        @jukebox.loop = true

        puts "...done!"
    end

    def setup_world
        puts "setting up game world..."

        #sample actors
        num_Sample_Actors = 5
        num_Physors = 2
        num_Diggers = 5
        num_Andys = 2
        num_Tanks = 0

        puts "creating #{num_Sample_Actors} SampleActors..."
        num_Sample_Actors.times  {
            @world.push SampleActor.new(:window => @window, :world => @world)
        }

        puts "creating #{num_Diggers} Diggers..."
        num_Diggers.times {
            @world.push Digger.new(:window => @window, :world => @world, :phys => @phys, :env => @env)
        }
        
        num_Physors.times {
            mag = rand(40) - 20
            @world.push Physor.new(:window => @window, :world => @world, :phys => @phys, :mag => mag)
            puts "creating Physor of mag #{mag}..."
        }

        puts "creating #{num_Andys} Andys..."
        num_Andys.times {
            @world.push Andy.new(:window => @window, :world => @world, :phys => @phys, :env => @env)
        }

        puts "creating #{num_Tanks/2.to_i} RedTanks..."
        (num_Tanks / 2).to_i.times {
            @world.push r=RedTank.new(:window => @window, :world => @world,
                                    :phys => @phys, :env => @env, :facing => 1)
            @ec.register_listener(:button_down, r)
        }

        puts "creating #{num_Tanks/2.to_i} GrayTanks..."
        (num_Tanks / 2).to_i.times {
            @world.push g=GrayTank.new(:window => @window, :world => @world,
                                       :phys => @phys, :env => @env, :facing => -1)
            @ec.register_listener(:button_down, g)
        }

        puts "randomizing positions of game actors..."
        @world.each { |thing| thing.warp(rand(2924), rand(500)) }

        #bring tanks into the world
        @world.push r=RedTank.new(:window => @window, :world => @world,
                                :phys => @phys, :env => @env, :facing => 1)

        @world.push g=GrayTank.new(:window => @window, :world => @world,
                                 :phys => @phys, :env => @env, :facing => -1)

        r.warp(110, 515)
        g.warp(1980, 464)

        @ec.register_listener(:button_down, r)
        @ec.register_listener(:button_down, g)

        #setting up environment
        @env.load_env("desert1")

        puts "...done!"
    end

    def update
        #update music
        @jukebox.update

        #update mouse & scrolling (mouse is responsible for scrolling)
        @mouse.update

        #update actors
        @world.each { |thing|  thing.update }
    end

    def draw
        #update scrolling info from mouse
        screen_x,screen_y = @mouse.screen_x, @mouse.screen_y

        @env.draw(screen_x,screen_y)
        @world.each { |thing|  thing.draw(screen_x,screen_y) }

        @mouse.draw

#        @font.draw("Player 1: Angle: #{360-@player1.angle}   Velocity: #{@player1.velocity}    Health: #{@player1.health}"+
#                   " "*48+
#                   "Player 2: Angle: #{@player2.angle}   Velocity: #{@player2.velocity}    Health: #{@player2.health}" ,
#                   10, 10, 3, 1.0, 1.0, 0xffffff00)
    end

    def button_down(id)
        @ec.button_down(id)
    end

end
