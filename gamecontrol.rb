begin
    require 'rubygems'
rescue LoadError
end

require 'utils'
require 'gosu'
require 'controllers'
require 'actors'
require 'tanks'
require 'environ'
require 'common'
require 'actordsl'

# Manages the game
class GameController

    GameState = Struct.new(:window, :world, :phys, :env, :ec, :mouse, :logging_level)

    LogLevel = 1
    
    def initialize(window)

        @gs = GameState.new
        @window = window
        @world = Array.new

        @jukebox = MusicSystem.new(@window)
        @anims = ImageSystem.new(@window)
        @phys = PhysicsController.new
        @ec = EventController.new
        @env = EnvironmentController.new(@window, @world, LogLevel)
        @mouse = MousePtr.new(@window, LogLevel, @world, @env, @ec)

        @gs.window = @window
        @gs.world = @world
        @gs.mouse = @mouse
        @gs.phys = @phys
        @gs.env = @env
        @gs.ec = @ec

        @gs.logging_level = LogLevel

        @actor_dsl = ActorDSL.new(@gs)

        setup_interface
        setup_world("helga1")

        puts "starting game."
    end

    def setup_interface
        puts "setting up interface..."
        #setting up font, and background
        @font = Gosu::Font.new(@window, Gosu::default_font_name, 20)

        #setting up mouse
       

        #setting up game music
        playlist = [@jukebox.load_song("assets/music/isee.ogg"),
                    @jukebox.load_song("assets/music/fugue.ogg"),
                    @jukebox.load_song("assets/music/lush.ogg")]
        
        @jukebox.make_play_list(:soundtrack, playlist)
        #@jukebox.load_play_list(:soundtrack)
        @jukebox.loop = true

        puts "...done!"
    end

    def setup_world(level)
        puts "setting up game world..."

        #setting up environment tiles
        width_height = @env.load_env(level)

        #setting up actors
        @actor_dsl.load_actors(level, *width_height)

        puts "...done!"
    end

    def update
        #update music
        #@jukebox.update

        #update mouse & scrolling (mouse is responsible for scrolling)
        @mouse.update

        #update actors
        @world.each { |thing|  thing.update }
    end

    def draw
        #update scrolling info from mouse
        screen_x, screen_y = @mouse.screen_x, @mouse.screen_y

        @env.draw(screen_x, screen_y)
        @world.each { |thing|  thing.draw(screen_x, screen_y) }

        @mouse.draw

        @font.draw("mouse (#{@mouse.x.to_i}, #{@mouse.y.to_i})", 840, 10, 3, 1.0, 1.0, 0xffffff00)
    end

    def button_down(id)
        @ec.button_down(id)
    end

end
