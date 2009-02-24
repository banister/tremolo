begin
    require 'rubygems'
rescue LoadError
end

require 'gosu'
require 'common'
require 'stateology'
require 'interface'
#require 'inline'

#provide bounding box functionality for game objects
module BoundingBox
    attr_accessor :x,:y
    attr_reader :x_offset
    attr_reader :y_offset

    # reduce bounding box size for more refined collisions
    Shrink = 0.7

    def set_bounding_box(xsize, ysize)

        @x_offset = xsize * Shrink / 2
        @y_offset = ysize * Shrink / 2
    end
    
    def intersect?(other)
        oy = other.y
        ox = other.x
        oy_offset = other.y_offset
        ox_offset = other.x_offset
       
        if @y - @y_offset < oy + oy_offset && @y + @y_offset > oy - oy_offset &&
                @x - @x_offset < ox + ox_offset && @x + @x_offset > ox - ox_offset then
            return true

        else
            return false
        end
    end
end
############## End BoundingBox ################


#Abstract base class for all objects in world
class Actor

    # mix in module functionality
    include Stateology
    include BoundingBox
    include InterfaceElementActor

    # state where nothing happens except drawing updates
    state(:Inactive) { 
        def update
        end
    }

    # state where actor is unresponsive to other actors
    state(:Idle) {
        def do_collision(collider)
        end
    }

    # important to use width/height, so as not to use *_offset of boundingbox module, stay loosely coupled
    attr_reader :width, :height

    def initialize(hash_args)
        check_args(hash_args, :game_state)

        @gs = hash_args[:game_state]
        @window = @gs.window
        @world = @gs.world
        @phys = @gs.phys
        @env = @gs.env
        @ec = @gs.ec

        if method(:basic_setup).arity == 0 then
            basic_setup
        else
            basic_setup(hash_args)
        end

        message "creating #{article self.class.to_s} #{self.class}", :log_level => 2
    end

    def basic_setup(hash_args)
        
        # Objects are born alive and interactive and self-propelled
        @x, @y = 0
        @cur_tile = nil
        @effects = EffectsSystem.new(@window)
        @anim_group = AnimGroup.new
        @timers = TimerSystem.new

        if method(:setup).arity == 0 then
            setup
        else
            setup(hash_args)
        end
    end

    # must be implemented by subclasses 
    def setup(hash_args); end

    def setup_sound(&block)
        @effects.instance_eval(&block)
    end

    def setup_gfx(hash_args={}, &block)
        h = { :x => method(:x),
            :y => method(:y)
        }.merge(hash_args)


        # get the destructor block for register_animation (if there is one)
        d = h.delete(:destructor)

        anim = register_animation(:self, h, &d) 

        anim.instance_eval(&block)

        image = anim.get_animation(:standard).first
        
        @width = image.width
        @height = image.height
        set_bounding_box(@width, @height)

        anim.load_animation(:standard)
        @anim = anim
    end

    def logging_level
        @gs.logging_level
    end

    def register_listener(event)
        @ec.register_listener(event, self)
    end

    def register_animation(sym, hash_args, &block)
        hash_args[:anim] = ImageSystem.new(@window, hash_args.delete(:facing))
        
        @anim_group.new_entry(sym, hash_args, &block)
    end

    def unregister_animation(sym)
        @anim_group.remove_entry(sym)
    end

    def animation_registered?(sym)
        @anim_group.has_entry?(sym)
    end

    def register_timer(*args)
        @timers.register_timer(*args)
    end

    def unregister_timer(*args)
        @timers.unregister_timer(*args)
    end

    def timer_update
        @timers.update
    end

    def timer_exist?(sym)
        @timers.exist?(sym)
    end

    def timer_touch(sym)
        @timers.touch(sym)
    end

    def play_effect(sym)
        @effects.play_effect(sym)
    end

    def add_to_world(obj)
        @world.push obj
    end

    def remove_from_world(obj)
        @cur_tile.remove_actor obj if @cur_tile
        @world.delete obj
    end

    def mouse
        @gs.mouse
    end

    def mouse_on?
        intersect?(@gs.mouse)
    end

    def check_mouse_collision
        do_mouse_collision if mouse_on?
    end

    #a stub
    def do_mouse_collision; end
    
    def check_actor_collision
        #@cur_tile ||= @env.get_tile(@x, @y)

        # actors aren't always in a tile, e.g falling off screen
        #return if !@cur_tile

        c_list = @world # @cur_tile.collision_list

        c_list.each do |thing|
            next if thing == self
            
            if intersect?(thing) then
                case thing
                when Tank

                else
                    self.do_collision(thing)
                    thing.do_collision(self)
                end
            end
        end
    end

    def current_collisions
        collision_list = []

        @world.each do |thing|
            next if thing == self
            
            if intersect?(thing) then
                collision_list.push(thing)
            end
        end

        collision_list
    end

    def check_tile_collision
        if tile=@env.check_collision(self, 0, @height / 2) then
            self.do_collision(tile)
            tile.do_collision(self)
        end
    end


    def actor_collision_with?(a)
        #@cur_tile ||= @env.get_tile(@x, @y)

        # actors aren't always in a tile, e.g falling off screen
        #return if !@cur_tile

        c_list = @world #@cur_tile.collision_list

        c_list.each do |thing|
            next if thing == self
            
            if intersect?(thing) then
                return true if thing == a
            end
        end
        false
    end
    

    def check_collision
        check_actor_collision
    end

    def check_bounds
        if @y > Common::SCREEN_Y * 13 || @y < -10 * Common::SCREEN_Y ||
                @x >Common::SCREEN_X * 13 || @x < -10 * Common::SCREEN_X then
            message "#{self.class} fell of the screen at (#{@x.to_i}, #{@y.to_i})", :log_level => 0
            remove_from_world(self)
        end 
    end

    def do_collision(collider)
        s_class = self.class.to_s
        c_class = collider.class.to_s

        message "#{article s_class} #{s_class} collided with #{article c_class} #{c_class}", :log_level => 2
    end

    def article(noun)
        noun[0, 1] =~ /[aeiou]/i ? "an" : "a"        
    end

#     def x=(v)
#         return @x = v if !@y

#         @x = v

#         t = @env.get_tile(@x, @y)

#         if @cur_tile != t then
#             t.add_actor(self) if t

#             @cur_tile.remove_actor(self) if @cur_tile

#             @cur_tile = t
#         end
#     end

#     def y=(v)
#         return @y = v if !@x

#         @y = v

#         t = @env.get_tile(@x, @y)

#         if @cur_tile != t then
#             t.add_actor(self) if t

#             @cur_tile.remove_actor(self) if @cur_tile

#             @cur_tile = t
#         end
#     end

    def warp(xv, yv)
        self.x = xv
        self.y = yv
    end

    def dist(o1, o2)
        Math::hypot(o1.x - o2.x, o1.y - o2.y)
    end

    # check to see whether object is currently on screen,
    # **SHOULD BE DEPRECATED SOON AS FUNCTIONALITY BEING MOVED TO AnimGroup Class**
    def visible?(sx,sy)
        (sx + @width / 2 > 0 && sx - @width / 2 < Common::SCREEN_X && sy + @height / 2 > 0 &&
         sy - @height / 2 < Common::SCREEN_Y)
    end

    def draw(ox,oy)
        @anim_group.draw(ox, oy)
    end        

    def update; end

    def info
        "Object information:\nType: #{self.class}"
    end

    def toggle_idle
        if state == nil then
            state :Idle
        elsif state == :Idle
            state nil
        end
    end

    def physical?
        false
    end

    private :visible?, :check_args
end
######################## End Actor ###########################

class VehicleActor < Actor
    include InterfaceElementVehicle

    NumberOfSeats = 3
    
    def basic_setup(hash_args)
        @drivers = []

        super
    end

    def add_driver(driver)
        if @drivers.size < NumberOfSeats
            @drivers.push driver
            driver.entered_vehicle(self)

            return driver
        end
        nil
    end

    def remove_driver
        driver = @drivers.shift
        driver.exited_vehicle(self) if driver
        driver
    end

    def driver_count
        @drivers.size
    end

    def has_driver?
        !@drivers.empty?
    end

    def drivers
        @drivers
    end

    def do_collision(collider)
        super

        if collider.kind_of?(Andy) && last_clicked?(collider) then
            if !animation_registered?(:vehicle_arrow) then
                create_vehicle_arrow
            end

            if timer_exist?(:vehicle_arrow_timeout) then
                timer_touch(:vehicle_arrow_timeout)

            else
                register_timer(:vehicle_arrow_timeout, :time_out => 0.2,
                               :action => lambda { unregister_animation(:vehicle_arrow) })
            end

            # change the mouse pointer NEW!
            if mouse_on? then
                 if mouse.cur_pointer != :on_vehicle then
                     mouse.change_pointer(:on_vehicle)
                 end
                
                if timer_exist?(:vehicle_pointer_timeout) then
                    timer_touch(:vehicle_pointer_timeout)
                else
                    register_timer(:vehicle_pointer_timeout, :time_out => 0.01,
                                   :action => lambda { mouse.change_pointer(:standard) })
                end
            end
            
         end
    end

    def create_vehicle_arrow
        hover = 2 * Math::PI * rand
        dy = 0
        y_float = lambda do
            hover = hover + 0.1 % (2 * Math::PI)
            dy = 10 * Math::sin(hover)
            method(:y).call + dy
        end

        new_anim = register_animation(:vehicle_arrow, :x => method(:x), :y => y_float, :x_offset => 0,
                                      :y_offset => -80, :zorder => Common::ZOrder::Interface)

        new_anim.make_animation(:standard, new_anim.load_image("assets/arrowb.png"), :timing => 1)

        new_anim.load_animation(:standard)
    end
end


# Basic functionality for Actors that respond to Physics
module Physical 
    include Stateology

    state(:Inactive) {
        def update
            check_collision
            @phys.get_field(self)
            timer_update
        end

        def check_collision
            check_actor_collision
        end

        def state_exit
            reset_physics
        end
    }

    attr_accessor :time, :init_x, :init_y
    attr_reader :phys_info

    def init_physics
        @time = @init_x = @init_y = 0
        @phys_info = { }
        @phys_info[:physical] = true
        @phys_info[:gravity_only] = false
    end

    def reset_physics
        @init_y = @init_x = 0
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
        val = do_physics
        self.x = val[0]
        self.y = val[1]
        
        check_bounds
        timer_update
    end

    private :reset_physics, :do_physics, :toggle_gravity_only, :toggle_physics, :gravity_only?

end
#################### End PhysicalActor #######################




