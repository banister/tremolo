begin
    # In cAse you use Gosu via RubyGems.
    require 'rubygems'
rescue LoadError
    # In case you don't.
end

require 'gosu'
require 'common'
require 'stateology'
require 'interface'

#provide bounding box functionality for game objects
module BoundingBox
    attr_reader :x,:y
    attr_reader :x_offset
    attr_reader :y_offset

    def set_bounding_box(xsize, ysize)

        #reduce bounding box size for more refined collisions
        shrink = 0.7
        @x_offset = xsize * shrink / 2
        @y_offset = ysize * shrink / 2
    end

    def intersect?(other)
        if !(@y - @y_offset > other.y+other.y_offset || @y + @y_offset < other.y - other.y_offset ||
             @x - @x_offset > other.x+other.x_offset || @x + @x_offset < other.x - other.x_offset) then
            return true

        else return false
        end
    end
end
############## End BoundingBox ################


#Abstract base class for all objects in world
class Actor

    #mix in the module with the class
    include Stateology
    include BoundingBox
    include InterfaceElementActor

    state(:Inactive) { 
        def update
        end
    }

    #each object can decide what this means: typically means object no longers moves of own volition if true
    attr_accessor :freeze

    #idle typically means the object is no longer interactive; expired means object should be erased from world
    attr_reader :idle, :expired

    #important to use width/height, so as not to use *_offset of boundingbox module, stay loosely coupled
    attr_reader :width, :height

    def initialize(hash_args)
        check_args(hash_args, :window)

        @window = hash_args[:window]
        
        basic_setup(hash_args)
    end

    def basic_setup(hash_args)
        
        #Objects are born alive and interactive and self-propelled
        @idle = false
        @expired = false
        @freeze = false
        @x, @y = 0

        @effects = EffectsSystem.new(@window)
        @anim = ImageSystem.new(@window)
        @anim_group = AnimGroup.new

        if method(:setup).arity == 0 then
            setup
        else
            setup(hash_args)
        end
        
    end

    #must be implemented by subclasses 
    def setup(hash_args); end

    def setup_sound(&block)
        @effects.instance_eval(&block)
    end

    def setup_gfx(&block)
        @anim.instance_eval(&block)

        image = @anim.get_animation(:standard).first
        
        @width = image.width
        @height = image.height
        set_bounding_box(@width,@height)

        @anim.load_animation(:standard)
    end

    def check_actor_collision
        @world.each do |thing|
            unless thing == self || thing.idle || thing.expired
                if intersect?(thing) then
                        case thing
                        when Player

                        else
                            self.do_collision(thing)
                            thing.do_collision(self)
                        end
                end
            end
        end
    end
    

    def check_collision
        check_actor_collision
    end

    def check_bounds
        if @y > Common::SCREEN_Y * 3 || @y < -Common::SCREEN_Y || @x >Common::SCREEN_X * 3 || @x < -Common::SCREEN_X then
            puts "#{self.class} fell of the screen at (#{@x.to_i}, #{@y.to_i})"
            @expired = true
        end 
    end

    def do_collision(collider)
        s_class = self.class.to_s
        c_class = collider.class.to_s

        # choose An or A depending on whether class name begins with a vowel
        article_one = s_class[0,1]=~/[aeiou]/i ? "An" : "A"
        article_two = c_class[0,1]=~/[aeiou]/i ? "an" : "a"
    end

    def warp(x, y)
        @x, @y = x,y
    end

    #check to see whether object is currently on screen
    def visible?(sx,sy)
        (sx + @width / 2 > 0 && sx - @width / 2 < Common::SCREEN_X && sy + @height / 2 > 0 &&
         sy - @height / 2 < Common::SCREEN_Y)
    end

    def draw(ox,oy)

        #screen coords
        sx = @x - ox
        sy = @y - oy

        return if !visible?(sx,sy)

        @anim.update.draw_rot(sx, sy, Common::ZOrder::Actor, 0)
    end        

    def update; end

    def info; "Object information:\nActor.info: this method needs to be overridden."; end

    def check_args(hash_args, *args)
        raise ArgumentError, "not a hash" if !hash_args.instance_of?(Hash)
        if (hash_args.keys & args).size != args.size then
            raise ArgumentError, "some required hash keys were missing"
        end
        nil
    end

    def physical?
        false
    end

    private :visible?, :check_args
end
######################## End Actor ###########################






# Basic functionality for Actors that respond to Physics
class PhysicalActor < Actor


    state(:Inactive) {
        def update
            check_collision
            @phys.get_field(self)
        end

        def check_collision
            check_actor_collision
        end
    }

    attr_accessor :time, :init_x, :init_y
    attr_reader :phys_info


    def basic_setup(hash_args)
        check_args(hash_args, :world, :phys, :env)

        @world = hash_args[:world]
        @phys = hash_args[:phys]
        @env = hash_args[:env]

        @time = @init_x = @init_y = @x = @y = 0
        @phys_info = { }
        @phys_info[:physical] = true
        @phys_info[:gravity_only] = false

        super
    end

    def reset_physics
        @phys.reset_physics(self)
    end

    def do_physics
        @phys.do_physics(self)
    end

    def toggle_physics
        @phys_info[:physical] = ! @phys_info[:physical]
    end

    def toggle_gravity_only
        @phys_info[:gravity_only] = ! @phys_info[:gravity_only]
    end

    def physical?
        @phys_info[:physical]
    end

    def gravity_only?
        @phys_info[:gravity_only]
    end

    def check_tile_collision
        
        if tile=@env.check_collision(self, 0, @height / 2) then
            reset_physics
            @init_y = 0
            @init_x = 0 
            self.do_collision(tile)
            tile.do_collision(self)
        end
    end

    def check_collision
        super

        check_tile_collision
    end


    def update
        check_collision
        @x, @y = do_physics
        check_bounds
    end

    private :reset_physics, :do_physics, :toggle_gravity_only, :toggle_physics, :gravity_only?

end
#################### End PhysicalActor #######################




# module for Actors that can be controlled by keyboard
module ControllableModule
    include Stateology

    def left_mouse_released
        self.freeze = false
        state :Controllable
    end


    state(:Controllable) {
        def do_controls
            if(last_clicked != self) then
                state nil
                return
            end
        end
        
    }

    def do_controls(*args, &block)
        #this should be left empty
        #as we want no behaviour outside
        #of the Controllable state
    end
end
#################### End ControllableModule ##################