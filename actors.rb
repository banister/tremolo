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
require 'base_classes'
require 'mouse'

#object with attractive/repulsive force
class Physor < Actor

    #magnitude of Physor (strength of force)
    attr_accessor :mag

    def setup(hash_args)
        setup_vars(hash_args)

        setup_sound do
            add_effect(:static,"assets/static.wav")
            add_effect(:vortex,"assets/vortex.wav")
        end

        img = @mag < 0 ? "assets/repulsor.png" : "assets/sphere.png"

        setup_gfx do
            make_animation(:standard, load_image(img))
        end
    end
    
    def setup_vars(hash_args)
        check_args(hash_args, :mag)
        
        @mag = hash_args[:mag]
        
        @phys.set_physor(self)
    end

    def within_range(actor,acc)
        if !intersect?(actor) then
            volume = [acc ** 3, 900.0].min / 900.0
            @effects.play_effect(:static,volume)
        end
    end

    def do_collision(collider)
        super
        if Projectile === collider then @effects.play_effect(:vortex); end
    end


    def info
        "#{super}; Magnitude: #{@mag}"
    end

#     def update
#         super
#         TexPlay.leftshift @anim.update, 2, :loop 
       
#     end

    private :setup_sound, :setup_gfx
end

#Simple interactable object, just for testing purposes
class SampleActor < Actor

    def setup
        # destructor lambda...what is executed when the graphics runs out frames
        destructor = lambda { remove_from_world(self) }
        
        setup_gfx(:destructor => destructor) do
            make_animation(:dying, load_frames("assets/lanternsmoke.png",20, 18),:timing => 0.05,
                           :loop => false, :hold => false)

            make_animation(:standard, load_frames("assets/lanternsmoke.png",20, 18).first)
        end

        setup_sound do
            add_effect(:puff,"assets/puff.wav")
        end
        @hover = 2 * Math::PI * rand
    end

    def warp(x, y)
        super
        @anchor = @y
    end

    def do_collision(collider)
        super
        @effects.play_effect(:puff)
        @anim.load_animation(:dying)
        state :Idle
    end

    def update
        @hover = @hover + 0.1 % (2 * Math::PI)
        @dy = 2 * Math::sin(@hover)
        self.y = @anchor + @dy
    end

    private :setup_sound, :setup_gfx
end

#Weaponry  object
class Projectile  < Actor

    include Physical

    def setup(hash_args)
        setup_vars(hash_args)
        
        setup_gfx do
            make_animation(:standard, load_image("assets/ball.png"))
        end

        setup_sound do
            add_effect(:bullet,"assets/bullet.wav")
        end
    end

    def setup_vars(hash_args)
        check_args(hash_args, :x, :y, :angle, :velocity, :owner)

        init_physics

        self.x = hash_args[:x]
        self.y = hash_args[:y]
        @owner = hash_args[:owner]

        angle = hash_args[:angle]
        velocity = hash_args[:velocity]

        @init_x = velocity * Math::cos((angle / 180) * Math::PI)  #initial velocity for x
        @init_y = velocity * Math::sin((angle / 180) * Math::PI)  #initial velocity for y
    end

    def do_collision(collider)
        super
        @owner.projectile_collided_with(collider, self)  #let owner know of collision
        
        case collider
        when Projectile
            @effects.play_effect(:bullet)
        end

        remove_from_world(self)
    end

    def info
        "#{super}; Initial Velocity: #{Math::hypot(@init_x,@init_y)}; Congrats on clicking me ;)"
    end

    private :check_collision, :setup_gfx, :setup_sound
end


#Digger object
class Digger  < VehicleActor
    include Stateology
    include Physical

    state(:Digging) {
        def state_entry(tile)
            @timer = Time.now.to_f
            @collide_tile = tile
            @anchor_y = self.y
        end

        def update
            if(Time.now.to_f - @timer) > 1 then
                state nil
            end

            self.y = @anchor_y + rand(4)

            collide_sound
        end

        def state_exit
            @collide_tile.do_collision(self, 0, @height/2)
            self.y = @anchor_y
            reset_physics
        end
    }

    def setup
        setup_gfx do 
            make_animation(:standard, load_image("assets/drill3.png"))
        end

        setup_sound do
            add_effect(:bullet,"assets/bullet.wav")
            add_effect(:drill,"assets/quake.ogg")
        end

        init_physics
        toggle_gravity_only
    end

    def do_collision(collider)
        super

        case collider
        when Projectile, Digger
            @effects.play_effect(:bullet)
            remove_from_world(self)
        when Tile
            if has_driver?
                state Digging, collider
            else
                reset_physics
            end
        end
    end

    def collide_sound
        @effects.play_effect(:drill, 0.05)
    end

    def check_collision
        check_actor_collision

        if(tile=@env.check_collision(self, 0, @height/2)) then

            self.do_collision(tile)
        end
    end

    def info
        "#{super}; Drivers: #{driver_count}"
    end
    private :check_collision, :setup_gfx, :setup_sound
end


#Andy object
class Andy  < Actor

    include Physical
    include InterfaceElementAndy

    JumpPower = 60

    state(:Controllable) {
        def state_entry
            # allow other forces
            toggle_gravity_only
        end
        
        def do_controls(control_id = nil)
            #block-based control keys
            @controls.each_value { |val| if (yield val) then control_id = val; break; end}

            #return self unless control_id

            #move right if nothing to the right
            if @controls[:right] == control_id && !@env.check_collision(self, @width / 2, 0) then
                self.x += 5
                ground_hug
                @anim.facing = 1

            #move left if nothing to the left
            elsif @controls[:left] == control_id && !@env.check_collision(self, -@width / 2, 0) then
                self.x -= 5
                ground_hug
                @anim.facing = -1

            #jump if nothing above, AND currently on the ground (i.e no jumping while in air)
            elsif @controls[:jump] == control_id && !@env.check_collision(self, 0, -@height / 2) &&
                @env.check_collision(self, 0, @height / 2) then

                self.y -= 10

                #set an upwards velocity
                @init_y = JumpPower
            else
                @anim.load_animation(:running)
            end

            return self
        end

        def ground_hug
            @y = @y.to_i
            prev = @y.to_i
            if @init_y == 0 then

                #why 12 ? cos this factor is perfect for climbing steep hills
                #if > 12 unnecessary looping (expensive) if < 12 then can't climb steep hills
                @y -= (@height / 8).to_i
                begin
                    @y += 1

                    #if ground is more than 30 pixels away then dont 'hug'; just fall instead
                    if (@y - prev) > 30 then
                        @y = prev
                        break
                    end
                end until @env.check_collision(self, 0, @height / 2)
            end
            self.y = @y
        end

        def state_exit
            # only allow gravity
            toggle_gravity_only
            @anim.load_animation(:standard)
        end
    }

    def setup
        setup_gfx do 
            make_animation(:standard, load_frames("assets/megaman2.png", 45, 62).first)
            make_animation(:running, load_frames("assets/megaman2.png", 45, 62), :timing => 0.075, :loop => true,
                           :hold => false )
        end

        setup_controls
        init_physics
        toggle_gravity_only
    end

    def setup_controls
        @controls = { :right => Gosu::Button::KbRight,
            :left => Gosu::Button::KbLeft,
            :jump => Gosu::Button::KbUp }
    end

    def update
        do_controls { |val| @window.button_down? val }
        check_collision
        apply_physics
        # ground_hug  ONLY run ground_hug if ground beneath is moving
        check_bounds
    end

    def apply_physics

        new_x, new_y = do_physics
        
        #if collide with tile on way up then begin descent immediately
        if @env.check_collision(self, 0, -@height / 2) then @init_y = 0 end
        
        #determine direction of new coords
        x_direc = new_x > @x ? 1 : -1
        y_direc = new_y > @y ? 1 : -1
        
        #don't apply horizontal physics if obstructions to the left or right
        if !@env.check_collision(self, x_direc * @width / 2, 0) then
            self.x = new_x
            ground_hug
        end
        
        #dont apply vertical physics if obstructions above or below
        if !@env.check_collision(self, 0, y_direc * @height / 2) then
            self.y = new_y
        end

    end

    def info
        "#{super} @ (#{@x.to_i}, #{@y.to_i})"
    end

    def ground_hug; end

    def check_collision
        check_actor_collision
        
        if tile=@env.check_collision(self, 0, @height / 2) then
            reset_physics
        end
    end

    def entered_vehicle(vehicle)
        # we entered a vehicle so we're no longer "in the world"
        state :Inactive
        toggle_physics
        remove_from_world(self)
    end

    def exited_vehicle(vehicle)
        add_to_world(self)
        warp(vehicle.x, vehicle.y)
        toggle_physics
        state nil
    end

    private :check_collision, :setup_gfx, :setup_sound
end


