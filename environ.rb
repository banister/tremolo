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
        @tile_theme[:evian] = EvianTile
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
                if tile=@tiles[y][x] then tile.draw(x,y,ox,oy);end
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

    Radius_Dmg = 30

    attr_reader :x,:y

    #meaningless but necessary for consistent interface
    def initialize(window, loglevel, env, map_to_screen, screen_to_map, t_type, x, y)
        @@count_instance += 1
        @window = window
        @logging_level = loglevel
        @env = env
        @map_to_screen = map_to_screen
        @screen_to_map = screen_to_map
        @t_type = t_type

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
        #get filename of tile image
        file = "assets/#{@theme}/#{@theme}#{@t_type}.png"

        @image = Gosu::Image.new(@window, file)

        @blast = Gosu::Image.load_tiles(@window,"assets/blast.png", 33, 32, false)

        @width = @image.width
        @height = @image.height
    end


    #standard, override in subclasses
    def setup_sound
        @effects = EffectsSystem.new(@window)
        @effects.add_effect(:thud, "assets/sand2.ogg")
    end

    #NOTE: equation is different from Actor's as Tiles are drawn from TOP LEFT, not center
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

    def draw(x,y,ox,oy)
        x,y = @map_to_screen.call(x,y)

        #screen coords
        sx = x - ox
        sy = y - oy

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
        if TexPlay.get_pixel(@image, sx, sy)[3] !=0 then return self;  end
    end

    #override in base-class
    def do_collision(actor, offset_x=0, offset_y=0)
        puts "A #{self.class} collided with a #{actor.class}" if logging_level > 1

        s = OpenStruct.new

        s.x = actor.x + offset_x
        s.y = actor.y + offset_y

        #convert from screen coords to local coords of tile, with origin at top left
        vx = s.x - @x
        vy = s.y - @y

        damage_block = lambda do
            #splash damage for other tiles
            tile = @env.get_tile(s.x + Radius_Dmg, s.y)
            if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end

            tile = @env.get_tile(s.x - Radius_Dmg, s.y)
            if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end

            tile = @env.get_tile(s.x, s.y  + Radius_Dmg)
            if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end

            tile = @env.get_tile(s.x, s.y  - Radius_Dmg)
            if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end

            tile = @env.get_tile(s.x - Radius_Dmg, s.y  - Radius_Dmg)
            if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end

            tile = @env.get_tile(s.x + Radius_Dmg, s.y  - Radius_Dmg)
            if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end

            tile = @env.get_tile(s.x - Radius_Dmg, s.y  + Radius_Dmg)
            if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end

            tile = @env.get_tile(s.x + Radius_Dmg, s.y  + Radius_Dmg)
            if(tile && tile != self) then tile.do_damage(s.x - tile.x, s.y - tile.y); end


            #damage for this tile
            do_damage(vx, vy)
       end

        case actor
        when Projectile
            @effects.play_effect(:thud)

            new_anim = @anim_group.new_entry(:blast, :x => actor.x, :y => actor.y,
                                             :anim => ImageSystem.new(@window), &damage_block)

            new_anim.make_animation(:blast, @blast,:timing => 0.06,:loop => false, :hold => false)

            new_anim.load_queue(:blast)
        when Digger
            damage_block.call
        else
            # no behaviour yet 
        end

    end

    def do_damage(x, y)
        r = Radius_Dmg
        TexPlay.draw(@image) {
            color :alpha
            circle x, y, r
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







