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
 class Player < Actor

  attr_accessor :angle
  attr_accessor :velocity
  attr_accessor :controls 
  attr_accessor :health  
       
  
  def initialize(window,world,tankdata,phys,env,facing=1,angle=0.0)    
    @window = window      
    @env = env
    @x , @y = 320, 240                                 #set default position for Player to center of the screen
    @angle = facing == -1 ? 180 : 0
    @velocity = 50
    @controls = {}
    @phys = phys
    @world = world
    @facing = facing
    @tank = tankdata
    @health = 100       
    
    @blast = Gosu::Image.load_tiles(@window,"assets/blast.png",33,32,false)                                #starting health for tank
    
    @misc_anims = []
    
    setup_tank
  end
  
  def setup_tank
    standard = @tank.anims.get_animation(:standard)[0]
    @width = standard.width
    @height = standard.height
    set_bounding_box(@width, @height)
    @tank.anims.load_animation(:standard)    
    @tank.turret.anims.load_animation(:standard)
  end
  
 
  def shoot 
    turret = @tank.turret
    
    x1 = @facing * turret.x + turret.length*Math::cos((@angle / 360.0) * (2 * Math::PI))     
    y1 = turret.y + turret.length * Math::sin(@angle / 360 * (2 * Math::PI))
    new_ball = Projectile.new(@window ,@x + x1, @y + y1,360 - @angle,@velocity,@facing,self,@world,@phys,@env)    

    #change turret animation
    turret.anims.load_queue(:fire,:standard)
    
    #sound effect
    @tank.effects.play_effect(:tankshot)
    
    #add new ball to world array
    @world.push(new_ball)   
        
  end
  
  def update 
    do_controls { |val| @window.button_down? val}
    check_collision                    
    return self
  end
  
  def do_controls(control_id=nil)
    
    #parameter-based control keys
    if(control_id): 
      shoot if @controls[:shoot_button] == control_id
      return self
    end
    
    #block-based control keys
    @controls.each_value { |val| if (yield val) then control_id=val; break; end} 
    
    return self unless control_id   
    
    da = dv = 0
    
    #modify angle
    if (@controls[:right] == control_id): da = 1.0; @tank.effects.play_effect(:turret,0.2); end
    if (@controls[:left] == control_id): da = -1.0; @tank.effects.play_effect(:turret,0.2); end
    
    #modify velocity
    dv = 1 if @controls[:vel_incr] == control_id
    dv = -1 if @controls[:vel_decr] == control_id 
    
    #update angle & velocity and keep within bounds
    @angle = (@angle + da) % 360
    @velocity = (@velocity + dv) % 1000
    
    return self
  end
  
  def check_collision    
    @world.each do |thing|
      unless thing==self || thing.idle || thing.expired 
        if intersect?(thing) then    
            case thing
                when Projectile            
                    img = @tank.anims.update
                    
                    x_orig = @x - (img.width/2)
                    y_orig = @y - (img.height/2)
                    
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
            
    return self
  end
  
  def projectile_collided_with(thing,projec)
    puts "Player's " + projec.class.to_s + " collided with a "+thing.class.to_s
    
    if(SampleActor === thing): @health+=5; end
  end
  
  def do_collision(thing) 
    super   
    
    #dont do collision behaviour if thing is not a projectile
    return if !(Projectile === thing)
    
    @health-=5 if @health > 0
            
    if @health <=0 then @tank.anims.load_queue(:burnedtank) end
        
    new_anim = OpenStruct.new(:x=>thing.x, :y=>thing.y, :anims=>ImageSystem.new(@window))
    
    new_anim.anims.make_animation(:blast,@blast,0.06,false,false)
    
    new_anim.anims.load_queue(:blast)
    
    @misc_anims <<  new_anim
    
    @tank.effects.play_effect(:tankexplode) 
    @idle = false
   end

  def draw(ox,oy)
    sx = @x - ox
    sy = @y - oy
    
    #still want to update even if tank not visible       
    tank_image = @tank.anims.update 
    turret = @tank.turret
    turret_image = turret.anims.update       
    
    return if !visible?(sx,sy) 
             
    tank_image.draw_rot(sx + rand() * 0.4, sy + rand() * 0.4, Common::ZOrder::Player, 0,0.5,0.5,@facing)    
    turret_image.draw_rot(sx + (@facing * turret.x),sy + turret.y,Common::ZOrder::Player,@angle,0,0.5)    
            
    
    @misc_anims.delete_if { |v| nil == v.anims.update }
    
    @misc_anims.each { |v|
        
        misc_image = v.anims.update 
        
        next if !misc_image
        
        misc_image.draw_rot(v.x - ox, v.y - oy, Common::ZOrder::Player, 0)
    }
    

         
    return self
    
  end
  
  def info
    "Object information:\nType: #{self.class}"
  end
  
  #private methods
  private :shoot, :check_collision, :setup_tank
  
  #aliases
  alias :button_down :do_controls
  
end

#support class to organize different tank types and associated animations/effects
class Tank
  attr_accessor :effects, :anims, :turret
  
   Turret_struct = Struct.new(:x,:y,:length,:anims)
  
  def initialize
    @turret = Turret_struct.new
  end
end
    
