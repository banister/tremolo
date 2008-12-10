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

    def initialize(window, phys, mag)
        super(window)
        @phys = phys
        @mag = mag
        @window = window

        @phys.set_physor(self)

        setup_gfx
        setup_sound
    end
    

    def setup_sound(&block)
        @effects = EffectsSystem.new(@window)
        @effects.add_effect(:static,"assets/static.wav")
        @effects.add_effect(:vortex,"assets/vortex.wav")

    end

    def setup_gfx
        @image = case @mag < 0
                 when true
                     Gosu::Image.new(@window,"assets/repulsor.png",false)
                 when false
                     Gosu::Image.new(@window, "assets/sphere.png", false)
                 end

        @width = @image.width
        @height = @image.height
        set_bounding_box(@width,@height)
    end

    def within_range(actor,acc)
        if !intersect?(actor) then
            volume = [acc**3,900.0].min/900.0
            @effects.play_effect(:static,volume)
        end
    end

    def do_collision(collider)
        puts "A #{self.class} of mag #{self.mag} collided with a #{collider.class}"
        if Projectile === collider then @effects.play_effect(:vortex); end
    end

    def draw(ox, oy)

        sx = @x - ox
        sy = @y - oy

        return if !visible?(sx,sy)
        @image.draw_rot(sx, sy, Common::ZOrder::Actor, 0.0)
    end

    def info
        "Object information:\nType: #{self.class}; Magnitude: #{@mag}"
    end

    private :setup_sound, :setup_gfx

end

#Simple interactable object, just for testing purposes
class SampleActor < Actor

    def setup
        setup_gfx do
            make_animation(:dying, load_frames("assets/lanternsmoke.png",20,18),:timing => 0.05,
                           :loop => false, :hold => false)

            make_animation(:standard, load_frames("assets/lanternsmoke.png",20,18).first, :timing => 1)
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
        @idle = true
    end

    def update
        @hover = @hover + 0.1 % (2 * Math::PI)
        @dy = 2 * Math::sin(@hover)
        @y = @anchor + @dy
    end

    def draw(ox,oy)
        #screen coords
        sx = @x - ox
        sy = @y - oy

        #no more frames left? then must have expired
        if !(image=@anim.update) then @expired = true; return; end

        #is visible? if not, return (no point drawing)
        return if !visible?(sx,sy)

        #object must be active and visible, so draw it
        image.draw_rot(sx, sy, Common::ZOrder::Actor, 0.0)
    end

    def info
        "Object information:\nType: #{self.class}"
    end

    private :setup_sound, :setup_gfx

end

#Weaponry  object
class Projectile  < PhysicalActor

    def initialize(window, x, y, angle, vel, owner, world, phys, env)
        super(window, world, phys, env)
        
        @x,@y = x,y       
        @owner = owner
        @init_x = vel * Math::cos((angle / 180) * Math::PI)  #initial velocity for x
        @init_y = vel * Math::sin((angle / 180) * Math::PI)  #initial velocity for y
    end

    def setup
        setup_gfx do
            make_animation(:standard, load_image("assets/ball.png"), :timing => 1)
        end

        setup_sound do
            add_effect(:bullet,"assets/bullet.wav")
        end

    end

    def do_collision(collider)
        super
        @owner.projectile_collided_with(collider,self)  #let owner know of collision
        case collider
        when Projectile
            @effects.play_effect(:bullet)
        end

        @expired = true
    end

    def info
        "Object information:\nType: #{self.class}; Initial Velocity: #{Math::hypot(@init_x,@init_y)}; Congrats on clicking me ;)"
    end

    private :check_collision, :setup_gfx, :setup_sound

end


#Digger object
class Digger  < PhysicalActor
    include Stateology

    state(:Digging) {
        def state_entry(tile)

            @timer = Time.now.to_f
            @ctile = tile
            @anchor_y = @y
        end

        def update

            if(Time.now.to_f - @timer) > 1 then
                state Default
            end

            #stop digging if selected by mouse
            state Default if freeze

            @y = @anchor_y + rand(4)

            collide_sound

        end

        def state_exit
            @ctile.do_collision(self, 0, @height/2)
            @y = @anchor_y
            @phys.reset_physics(self)
        end
    }


    def setup

        setup_gfx do 
            make_animation(:standard, load_image("assets/drill3.png"), :timing => 1, :hold => true)
        end

        setup_sound do
            add_effect(:bullet,"assets/bullet.wav")
            add_effect(:drill,"assets/quake.ogg")
        end
            

    end

    def do_collision(collider)
        super

        case collider
        when Projectile, Digger
            @effects.play_effect(:bullet)
            @expired = true

        end

    end

    def collide_sound
        @effects.play_effect(:drill, 0.05)
    end

    def check_collision
        check_actor_collision

        if(tile=@env.check_collision(self, 0, @height/2)) then

            #when collide with tile, change state to :Digging, maybe put this in the self.do_collision ?
            state Digging, tile

            #pretty much no self collision behaviour, all of it occurs in the tile
            self.do_collision(tile)
        end
    end

    def info
        "Object information:\nType: #{self.class}"
    end

    private :check_collision, :setup_gfx, :setup_sound

end




#Andy object
class Andy  < PhysicalActor
    
    include ControllableModule

    state(:Controllable) {
        def do_controls(control_id = nil)
            super()
            
            #block-based control keys
            @controls.each_value { |val| if (yield val) then control_id = val; break; end}

            return self unless control_id

            #move right if nothing to the right
            if @controls[:right] == control_id && !@env.check_collision(self, @width / 2, 0) then
                @x+=5
                ground_hug
            end

            #move left if nothing to the left
            if @controls[:left] == control_id && !@env.check_collision(self, -@width / 2, 0) then
                @x-=5
                ground_hug
            end

            #jump if nothing above, AND currently on the ground (i.e no jumping while in air)
            if @controls[:jump] == control_id && !@env.check_collision(self, 0, -@height / 2) &&
                @env.check_collision(self, 0, @height / 2) then

                @y-=10

                #set an upwards velocity
                @init_y = 60
            end

            return self
        end
    }

    def setup

        setup_gfx do 
            make_animation(:standard, load_image("assets/dude.png"), :timing => 1, :hold => true)
        end

        setup_controls
 
    end

    def setup_controls
        @controls = { :right => Gosu::Button::KbRight, :left => Gosu::Button::KbLeft,
            :jump => Gosu::Button::KbUp }
    end

    def update
        do_controls { |val| @window.button_down? val }
        check_collision
        apply_physics
        check_bounds
    end

    def apply_physics

        new_x, new_y = @phys.do_physics(self)
        
        #if collide with tile on way up then begin descent immediately
        if @env.check_collision(self, 0, -@height/2) then @init_y = 0 end

        #determine direction of new coords
        x_direc = new_x > @x ? 1 : -1
        y_direc = new_y > @y ? 1 : -1

        #don't apply horizontal physics if obstructions to the left or right
        if !@env.check_collision(self, x_direc * @width/2, 0)  then
            @x = new_x
            ground_hug 
        end

        #dont apply vertical physics if obstructions above or below
        if !@env.check_collision(self, 0, y_direc * @height/2) then
            @y = new_y
        end
        
    end

    def info
        "Object information:\nType: #{self.class} @ (#{@x.to_i}, #{@y.to_i})"
    end

    #ensure Andy follows curve of landscape
    def ground_hug
        prev = @y
        if @init_y == 0 then

            #why 12 ? cos this factor is perfect for climbing steep hills
            #if > 12 unnecessary looping (expensive) if < 12 then can't climb steep hills
            @y-=@height / 12
            begin
                @y+=1

                #if ground is more than 30 pixels away then dont 'hug'; just fall instead
                if (@y - prev) > 30 then
                    @y = prev
                    break
                end
            end until @env.check_collision(self, 0, @height / 2)
        end
    end


    private :check_collision, :setup_gfx, :setup_sound

end


