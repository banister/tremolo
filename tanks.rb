begin
    # In case you use Gosu via RubyGems.
    require 'rubygems'
rescue LoadError
    # In case you don't.
end

require 'ostruct'
require 'gosu'
require 'common'


#Interactive player object
class Tank < Actor

    include ControllableModule

    Health_init = 100
    Velocity_init = 50

    state(:Controllable) { 
        def do_controls(control_id=nil)
            
            #parameter-based control keys
            if control_id then
                shoot if @controls[:shoot_button] == control_id
                return
            end

            #block-based control keys
            @controls.each_value { |val| if (yield val) then control_id=val; break; end}

            return unless control_id

            da = dv = 0

            #modify angle
            if @controls[:right] == control_id then da = 1.0; @effects.play_effect(:turret,0.2); end
            if @controls[:left] == control_id then da = -1.0; @effects.play_effect(:turret,0.2); end

            #modify velocity
            dv = 1 if @controls[:vel_incr] == control_id
            dv = -1 if @controls[:vel_decr] == control_id

            #update angle & velocity and keep within bounds
            @angle = (@angle + da) % 360
            @velocity = (@velocity + dv) % 1000
        end

        alias_method :button_down, :do_controls
    }

    def setup_vars(hash_args)
        check_args(hash_args, :phys, :env)

        @phys = hash_args[:phys]
        @env = hash_args[:env]
        @facing = hash_args[:facing] || 1
        
        @angle = @facing == -1 ? 180 : 0
        @health = Health_init
        @velocity = Velocity_init
        @blast = Gosu::Image.load_tiles(@window,"assets/blast.png",33,32,false)

        @turret = OpenStruct.new
    end

    def setup_controls; end
    
    def setup_turret
        @turret.length = 38
        @turret.anim = ImageSystem.new(@window)
        @turret.anim.instance_eval do
            make_animation(:standard, load_image("assets/turret.png"),
                           :timing => 1, :loop => false)
            make_animation(:fire, load_frames("assets/canblast.png",40,27),
                           :timing => 0.06, :loop => false)
        end

        @turret.anim.load_animation(:standard)
    end

    def shoot
        x1 = @facing * @turret.x + @turret.length * Math::cos((@angle / 360.0) * (2 * Math::PI))
        y1 = @turret.y + @turret.length * Math::sin(@angle / 360 * (2 * Math::PI))
        
        new_ball = Projectile.new(:window => @window ,:x => @x + x1, :y =>  @y + y1,
                                  :angle => 360 - @angle, :velocity => @velocity, :owner => self,
                                  :world => @world, :phys => @phys, :env => @env)
        
        # change turret animation
        @turret.anim.load_queue(:fire, :standard)

        # sound effect
        @effects.play_effect(:tankshot)

        # add new ball to world array
        add_to_world(new_ball)
    end

    def update
        do_controls { |val| @window.button_down? val}
        check_collision
    end

    def check_collision
        @world.each do |thing|
            unless thing == self
                if intersect?(thing) then
                    case thing
                    when Projectile
                        img = @anim.update

                        x_orig = @x - (img.width / 2)
                        y_orig = @y - (img.height / 2)

                        rel_x = (thing.x - x_orig).to_i
                        rel_y = (thing.y - y_orig).to_i

                        if @facing == 1 then
                            pixel = TexPlay.get_pixel(img, (thing.x - x_orig).to_i, (thing.y - y_orig).to_i)
                            return if !pixel
                            pixel = pixel[3] != 0
                        else
                            pixel = TexPlay.get_pixel(img, img.width - (thing.x - x_orig).to_i, (thing.y - y_orig).to_i)
                            return if !pixel
                            pixel = pixel[3] != 0
                        end

                        if(pixel) then
                            self.do_collision(thing)
                            thing.do_collision(self)
                        end

                    else
                        self.do_collision(thing)
                        thing.do_collision(self)
                    end

                end
            end
        end
    end

    def projectile_collided_with(thing, projec)
        puts "#{self.class}'s #{projec.class} collided with a #{thing.class}"

        if thing.instance_of?(SampleActor) then @health += 5; end
    end

    def do_collision(thing)
        super

        #dont do collision behaviour if thing is not a projectile
        return if !(Projectile === thing)

        @health -= 5 if @health > 0

        if @health <= 0 then @anim.load_queue(:burnedtank) end

        new_anim = @anim_group.new_entry(:blast, :x => thing.x, :y => thing.y,
                                         :anim => ImageSystem.new(@window))
        new_anim.make_animation(:blast, @blast, :timing => 0.06, :loop => false, :hold => false)
        new_anim.load_animation(:blast)
        @effects.play_effect(:tankexplode)
    end

    def draw(ox,oy)
        sx = @x - ox
        sy = @y - oy

        timg = @turret.anim.update
        
        return if !visible?(sx, sy)

        timg.draw_rot(sx + (@facing * @turret.x),sy + @turret.y,Common::ZOrder::Player, @angle, 0, 0.5)

        @anim_group.draw(ox, oy)
    end

    def info
        "#{super}; Health: #{@health}"
    end

    def facing
        @facing
    end

    #private methods
    private :shoot, :check_collision, :facing

    alias_method :button_down, :do_controls
end


class RedTank < Tank
    def setup(hash_args)
        setup_vars(hash_args)
        setup_controls
        setup_turret
        setup_sound do
            add_effect(:tankexplode,"assets/tankexplode.wav")
            add_effect(:tankshot,"assets/tankshot.wav")
            add_effect(:turret,"assets/turret.wav")
        end
        setup_gfx(:facing => facing) do
            make_animation(:standard, load_image("assets/rtank.png"), :timing => 1, :loop => false)
            make_animation(:burnedtank, load_image("assets/tankburned.png"), :timing => 1, :loop => false)
        end
    end

    def setup_turret
        super

        @turret.x = 24
        @turret.y = -7
    end

    def setup_controls
        @controls =  {:right => Gosu::KbD, :left => Gosu::KbA,
            :vel_incr => Gosu::KbW, :vel_decr => Gosu::KbS,
            :shoot_button => Gosu::Button::KbSpace}
    end
end

class GrayTank < Tank
    def setup(hash_args)
        setup_vars(hash_args)
        setup_controls
        setup_turret
        
        setup_sound do
            add_effect(:tankexplode,"assets/tankexplode.wav")
            add_effect(:tankshot,"assets/tankshot.wav")
            add_effect(:turret,"assets/turret.wav")
        end
        
        setup_gfx(:facing => facing) do
            make_animation(:standard, load_image("assets/gtank.png"), :timing => 1, :loop => false)
            make_animation(:burnedtank, load_image("assets/tankburned.png"), :timing => 1, :loop => false)
        end
    end

    def setup_turret
        super

        @turret.x = 25
        @turret.y = 0
    end

    def setup_controls
        @controls =  {:right => Gosu::Button::KbRight, :left => Gosu::Button::KbLeft,
            :vel_incr => Gosu::Button::KbUp, :vel_decr => Gosu::Button::KbDown,
            :shoot_button => Gosu::Button::KbEnter}
    end
end
