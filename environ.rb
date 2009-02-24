begin
    # In case you use Gosu via RubyGems.
    require 'rubygems'
rescue LoadError
    # In case you don't.
end

require 'gosu'
require 'common'
require 'texplay'
require 'interface'

#manages environment (landscape)
class EnvironmentController

    TileSize_X = 400 #420
    TileSize_Y = 350 #322

    Offset_X = 0
    Offset_Y = 124


    def initialize(window, world, loglevel)

        @window = window
        @world = world
        @logging_level = loglevel
        @tile_theme = {}

        #mapping functions
        @map_to_screen = lambda { |x,y| [x * TileSize_X, Offset_Y + y * TileSize_Y] }
        @screen_to_map = lambda { |x,y| [(x / TileSize_X).to_i, ((y - Offset_Y) / TileSize_Y).to_i] }

        setup_themes
    end

    def logging_level
        @logging_level
    end

    def setup_themes
        @tile_theme[:desert] = DesertTile
        @tile_theme[:lush] = LushTile
        @tile_theme[:helga] = HelgaTile
    end

    def load_env(thememap)
        num_tiles = 0

        #break up the parameter into its theme and map number components
        theme, map = thememap.scan(/\d+|\D+/)

        #set path for this theme
        theme_path = "assets/#{theme}/"

        #map file
        mapfile = "#{theme_path}map#{map}"

        #load the background
        @bg = Gosu::Image.new(@window, "#{theme_path}bg.png")

        lines = File.readlines(mapfile).map { |line| line.chop }

        puts "loading environment..."
        puts "theme is: #{theme}; map is: map#{map}"

        @height = lines.size
        @width = lines[0].size

        num_tiles = @width * @height 

        puts "#{num_tiles} tiles in the environment..."
        @tiles = Array.new(@height) do |y|
            Array.new(@width) do |x|
                t_type = lines[y][x, 1]
                @tile_theme[theme.to_sym].new(@window, @logging_level, self,
                                              @map_to_screen, @screen_to_map, t_type, x, y)
            end
        end

        puts "...done!"

        # return x and y limits (in pixels) of map
        [ @width * TileSize_X, @height * TileSize_Y ]
    end

    def get_tile(x,y)
        #convert from screen to map coords
        map_x, map_y = *@screen_to_map.call(x,y)

        if x < 0 || y < 0 then return nil; end
        if !@tiles[map_y] then return nil; end

        if @tiles[map_y][map_x] then
                return @tiles[map_y][map_x]
        end
        
        return nil
    end

    def check_collision(actor, offset_x=0, offset_y=0)

        x = actor.x + offset_x
        y = actor.y + offset_y

        #convert from screen to map coords
        map_x, map_y = @screen_to_map.call(x, y)

        if x < 0 || y < 0 then return; end
        if !@tiles[map_y] then return; end

        if @tiles[map_y][map_x] then
            tile = @tiles[map_y][map_x]
            return tile.check_collision(x, y)
        end
    end

    def draw(ox,oy)

        #draw the background
        @bg.draw(0, 0, Common::ZOrder::Background)

        #draw the tiles
        @height.times do |y|
            @width.times do |x|
                if tile=@tiles[y][x] then tile.draw(x,y,ox,oy) end
            end
        end
    end

end

#abstract base class for tile
class Tile

    include InterfaceElementTile
    
    #class counter
    @@count_instance = 0

    #utility class
    Clr = Struct.new(:r,:g,:b,:a)

    Radius_Dmg = 25

    attr_reader :x,:y

    def initialize(window, loglevel, env, map_to_screen, screen_to_map, t_type, x, y)
        @@count_instance += 1
        @window = window
        @logging_level = loglevel
        @env = env
        @map_to_screen = map_to_screen
        @screen_to_map = screen_to_map
        @t_type = t_type
        @particles = Array.new

        #TEMPORARY, FIX SOON
        @drillmask = Gosu::Image.new(@window, "assets/drillmask.png") 

        #for misc animations associated with this tile
        @anim_group = AnimGroup.new

        @x, @y = @map_to_screen.call(x,y)

        #list of Actors within boundaries of this tile (collision list)
        @c_list = []

        puts "loading tile #{@@count_instance}.."

        #define in subclass
        set_theme

        setup_gfx
        setup_sound
    end

    def logging_level
        @logging_level
    end

    def set_theme
        @theme = ""
    end

    def setup_gfx
        # get filename of tile image
        file = "assets/#{@theme}/#{@theme}#{@t_type}.png"

        @image = Gosu::Image.new(@window, file, false)

        @smoke = Gosu::Image.new(@window, "assets/smoke.png")
        @explode =  Gosu::Image.load_tiles(@window, "assets/explosion.png", 128,
                                           128, false)

        @width = @image.width
        @height = @image.height
    end


    # standard, override in subclasses
    def setup_sound
        @effects = EffectsSystem.new(@window)
        @effects.add_effect(:thud, "assets/sand2.ogg")
    end

    # NOTE: equation is different from Actor's as Tiles are drawn from TOP LEFT, not center
    def visible?(sx,sy)
        (sx + @width > 0 && sx < Common::SCREEN_X && sy + @height > 0 &&
         sy < Common::SCREEN_Y)
    end

    def add_actor(actor)
        @c_list << actor
    end

    def remove_actor(actor)
        @c_list.delete(actor)
    end

    def collision_list
        @c_list
    end

    def draw(x, y, ox, oy)
        x,y = @map_to_screen.call(x,y)

        #screen coords
        sx = x - ox
        sy = y - oy

        @particles.each { |v| v.update; v.draw(ox, oy) }

        return if !visible?(sx,sy)
        
        @image.draw(sx, sy, Common::ZOrder::Tile)


        @anim_group.draw(ox, oy)

        #if @x == 400 then TexPlay.leftshift @image, 2, :loop end   #CHANGED!
    end

    def check_collision(cp_x, cp_y)

        sx = (cp_x - @x).to_i
        sy = (cp_y - @y).to_i

        #might need to add tests for other directions too (e.g sx < 0 && sx > MAX && sy > MAX etc)
        return if sy < 0 
        if @image.get_pixel(sx, sy)[3] !=0 then return self;  end
    end

    def splash_damage_center(x, y, x_width, y_width, meth_name)
        
        #splash damage for other tiles
        tile = @env.get_tile(x + x_width, y)
        if(tile && tile != self) then tile.send meth_name, x - tile.x, y - tile.y; end

        tile = @env.get_tile(x - x_width, y)
        if(tile && tile != self) then tile.send meth_name, x - tile.x, y - tile.y; end

        tile = @env.get_tile(x, y  + y_width)
        if(tile && tile != self) then tile.send meth_name, x - tile.x, y - tile.y; end

        tile = @env.get_tile(x, y  - y_width)
        if(tile && tile != self) then tile.send meth_name, x - tile.x, y - tile.y; end

        tile = @env.get_tile(x - x_width, y  - y_width)
        if(tile && tile != self) then tile.send meth_name, x - tile.x, y - tile.y; end

        tile = @env.get_tile(x + x_width, y  - y_width)
        if(tile && tile != self) then tile.send meth_name, x - tile.x, y - tile.y; end

        tile = @env.get_tile(x - x_width, y  + y_width)
        if(tile && tile != self) then tile.send meth_name, x - tile.x, y - tile.y; end

        tile = @env.get_tile(x + x_width, y  + y_width)
        if(tile && tile != self) then tile.send meth_name, x - tile.x, y - tile.y; end


        #damage for this tile
        send meth_name, x - @x, y - @y
    end

    #override in base-class
    def do_collision(actor, offset_x=0, offset_y=0)
        message "A #{self.class} collided with a #{actor.class}", :log_level => 2

        sx = actor.x + offset_x
        sy = actor.y + offset_y

        damage_block = lambda do 
            splash_damage_center(sx, sy, Radius_Dmg + 8, Radius_Dmg + 8, :do_damage_proj)
       end

        case actor
        when Projectile
            @effects.play_effect(:thud)

            splash_damage_center(sx, sy, Radius_Dmg + 8, Radius_Dmg + 8, :do_damage_proj)

            new_anim = @anim_group.new_entry(:blast, :x => actor.x, :y => actor.y,
                                             :anim => ImageSystem.new(@window))
 
            new_anim.make_animation(:blast, @explode,
                                    :timing => 0.06,:loop => false, :hold => false)
 
            new_anim.load_queue(:blast)

            5.times {
                Particle.new(@window, @smoke,
                             actor.x, actor.y, @particles, :fade_rate => 4, :scale => 0.5, :speed => 3)
            }
            
        when Digger
            splash_damage_center(sx, sy, (@drillmask.width / 2), (@drillmask.height / 2), :do_damage_drill)
            
            16.times {
                Particle.new(@window, @smoke,
                             actor.x, actor.y + offset_y - 50 + rand(5), @particles,
                             :speed => 2, :scale => :rand, :fade_rate => 1,
                             :x_scatter => @smoke.width, :y_scatter => @smoke.height)
            }
            
        else
            # no behaviour yet 
        end

    end

    def do_damage_drill(x, y)
        
        @image.paint { |c|
            c.splice(@drillmask, x - (@drillmask.width / 2), y - (@drillmask.height / 2), :mask => :_white)
        }
    end

    def do_damage_proj(x, y)

        @image.paint { |c|
            5.times {
                dx = rand(16) - 8
                dy = rand(16) - 8

                c.color :alpha
                c.circle x + dx, y + dy, Radius_Dmg
            }
        }
    end

    
    def info
        "Object information:\nType: #{self.class}; Sub-type: #{@t_type}"
    end

    #round x to nearest multiple of y
    def round_to_mult(x,y)
        (x / y.to_f).round * y
    end

    private :round_to_mult, :setup_gfx, :setup_sound, :visible?

end

class Particle
    def initialize(window, anim, x, y, particles, options={})
        @options = {
            :scale => 1,
            :speed => 1,
            :fade_rate => 1,
            :x_scatter => anim.width,
            :y_scatter => anim.height
        }.merge(options)

        if @options[:scale] == :rand then
            @options[:scale] = rand * 0.70
        end
        
        # All Particle instances use the same image
        @image = anim
        @particles = particles
        scale = @options[:scale]
        x_scatter = @options[:x_scatter]
        y_scatter = @options[:y_scatter]
        
        @x = (x + rand(x_scatter) * scale - (x_scatter * scale / 2)).to_i
        @y = (y + rand(y_scatter) * scale  - (y_scatter * scale / 2)).to_i
        
        @color = Gosu::Color.new(255, 255, 255, 255)
        
        @particles.push self
    end
    
    def update
        @y -= @options[:speed]
        @x = @x - 1 + rand(3)

        fade_rate = @options[:fade_rate]
        
        @color.alpha -= @color.alpha >= fade_rate ? @options[:fade_rate] : 1
        
        # Remove if faded completely.
        if @y < 0 || @color.alpha <= 0 then
            @particles.delete(self)
        end
        
        def draw(ox, oy)
            scale = @options[:scale]
            @image.draw_rot(@x - ox, @y - oy, 1, 0, 0.5, 0.5, scale, scale, @color)
        end
        
    end
end

#desert tile class
class DesertTile < Tile
    def set_theme
        @theme = "desert"
    end
end

#desert tile class
class LushTile < Tile
    def set_theme
        @theme = "lush"
    end
end

#helga tile class
class HelgaTile < Tile
    def set_theme
        @theme = "helga"
    end
end

class EvianTile < Tile
    def set_theme
        @theme = "evian"
    end
end







