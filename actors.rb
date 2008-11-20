begin
  # In case you use Gosu via RubyGems.
  require 'rubygems'
rescue LoadError
  # In case you don't.
end

require 'gosu'
require 'common'
require 'stateology'

#provide bounding box functionality for game objects
module BoundingBox
  attr_reader :x,:y  
  attr_reader :x_offset
  attr_reader :y_offset
  
  def set_bounding_box(xsize, ysize) 
  
    #reduce bounding box size for more refined collisions
    shrink=0.7  
    @x_offset = xsize*shrink/2
    @y_offset = ysize*shrink/2                 
   end
  
  def intersect?(other)
      if(!(@y-@y_offset > other.y+other.y_offset || @y+@y_offset < other.y-other.y_offset || 
            @x-@x_offset > other.x+other.x_offset || @x+@x_offset < other.x-other.x_offset)) then return true
      else return false
      end
   end
end
      
#mouse class
class MousePtr
  include BoundingBox
  
  #screen coordinates of mouse
  attr_accessor :rx, :ry
  
  #scrolling variables
  attr_reader :screen_x, :screen_y
  
  def initialize(window,world,env)
    @window=window
    @world=world
    @env=env
    @image=Gosu::Image.load_tiles(@window,"assets/crosshair.png",67,67,false)[0] 
    @x=Common::SCREEN_X/2
    @y=Common::SCREEN_Y/2
    @rx,@ry=@x,@y
    @left_held=false
    
    #scrolling vars
    @screen_x=0  
    @screen_y=0
    @scroll_border_x=200     
    @scroll_border_y=50
    @scroll_speed=12
    @no_scroll=false
    
    #standard size bb
    set_bounding_box(50,50) 
  end
    
  #scrolling & ensure mouse isn't in start/asleep state (both y & x==0 at start before first move)
  #variable rate scrolling in proportion to distance to screen edge
  def do_scroll
  
    #don't scroll if @no_scroll flag is set
    return if(@no_scroll)
    
    #x axis
    if(@rx<=@scroll_border_x && (@rx!=0 && @ry!=0)): 
      @screen_x-=@scroll_speed*((@scroll_border_x-@rx)/@scroll_border_x.to_f)
    elsif(@rx>=Common::SCREEN_X-@scroll_border_x): 
      @screen_x+=@scroll_speed*((@rx-(Common::SCREEN_X-@scroll_border_x))/@scroll_border_x.to_f)
    end
    
    #y axis
    if(@ry<=@scroll_border_y && (@ry!=0 && @ry!=0)): 
      @screen_y-=@scroll_speed*((@scroll_border_y-@ry)/@scroll_border_y.to_f)
    elsif(@ry>=Common::SCREEN_Y-@scroll_border_y): 
      @screen_y+=@scroll_speed*((@ry-(Common::SCREEN_Y-@scroll_border_y))/@scroll_border_y.to_f)
    end
  end
    
  #manage mouse button presses
  def check_controls 
    
    #remember, button_down() method can also set @left_pressed to true 
    #remember, can't always rely on polling to detect button press (reason for use of button_down() method)  
    #also remember, below NOT equivalent to @left_pressed=@window...etc; due to potential polling problems.
    @left_pressed=true if @window.button_down?(Gosu::Button::MsLeft)
    
    #was left mouse button pressed?
    if @left_pressed:      
      
      #button is not currently being held down? (i.e initial press)
      if(!@left_held):          
      
        #display information about the object(s) selected                 
        if(objs=selected):        
        
          #select object closest to center of target   
          @selec_obj=objs.inject { |m,c| dist(self,m) < dist(self,c) ? m : c } 
          
          #display object information
          puts @selec_obj.info                    
          
          #freeze the object (stop its movement)
          @selec_obj.freeze=true
          
          #is it an Actor? exclude non-actors from drag & drop
          @selec_obj=nil if !(Actor===@selec_obj)
                
        end
        
      #button is currently being held down, so try to 'drag' the object around.
      elsif(@left_held && @selec_obj):   
      
        #bind the object xy to mouse xy for duration @left_held is true
        @selec_obj.warp(@x,@y) 
      
        
        #release object if it's expired        
        @selec_obj=nil if @selec_obj.expired
                    
      end
      
      #button press logic
      @left_held=true       
      @left_pressed=false   
      
    #button is no longer being pressed, so restore original bounding box
    else  
            
      #button press logic
      @left_held=false  
      
      #unfreeze objects
      @selec_obj.freeze=false if @selec_obj
      
      #release expired objects for garbage collection (if @selec_obj is only ref to obj)
      @selec_obj=nil
      
    end
    
  end
  
  #distance between 2 Actors
  def dist(o1,o2)
    Math::hypot(o1.x-o2.x,o1.y-o2.y)
  end
    

  def button_down(id)    
    #this is neccesary as sometimes polling doesn't pick up on a button-press
    if (id==Gosu::Button::MsLeft): @left_pressed=true; end
    
    #toggle @no_scroll flag, turns on/off scrolling
    if (id==Gosu::Button::MsRight): @no_scroll=!@no_scroll; puts "no scroll is: #{@no_scroll}"; end 
  end
  
  def update
    
    #update scrolling
    do_scroll
    
    #buttons clicked?
    check_controls
    
    #screen coords
    @rx=@window.mouse_x
    @ry=@window.mouse_y
    
    #actual(game) coords
    @x=@window.mouse_x+screen_x
    @y=@window.mouse_y+screen_y
        
  end
  
  def draw
    @image.draw_rot(@rx,@ry,Common::ZOrder::Mouse,0.0)
  end
  
  #determine game object selected by mouse
  def selected  
   things=[]
   @world.each do |thing|
      unless thing==self || thing.idle || thing.expired    
         if intersect?(thing):          
            things.push(thing)                      
         end
      end
    end       
        
    if(tile=@env.check_collision(self)):
      things.push(tile)
    end
      
    return things if !things.empty?
  end
  
  private :dist, :selected, :check_controls, :do_scroll
  
end

#Abstract base class for all objects in world
class Actor

  #mix in the module with the class
  include BoundingBox  
  
  #each object can decide what this means: typically means object no longers moves of own volition if true
  attr_accessor :freeze
  
  #idle typically means the object is no longer interactive; expired means object should be erased from world
  attr_reader :idle, :expired

  #important to use width/height, so as not to use *_offset of boundingbox module, stay loosely coupled
  attr_reader :width, :height
  
  def initialize    
    #Objects are born alive and interactive and self-propelled
    @idle = false
    @expired = false
    @freeze = false
  end
  
  def do_collision(collider)
    s_class = self.class.to_s
    c_class = collider.class.to_s
        
    # choose An or A depending on whether class name begins with a vowel    
    article_one = s_class[0,1]=~/[aeiou]/i ? "An" : "A" 
    article_two = c_class[0,1]=~/[aeiou]/i ? "an" : "a" 
    
    puts "#{article_one} #{s_class} collided with #{article_two} #{c_class}"
  end
  
  def warp(x, y)
    @x,@y = x,y   
  end
  
  #check to see whether object is currently on screen
  def visible?(sx,sy)
    (sx + @width / 2 > 0 && sx-@width/2 < Common::SCREEN_X && sy + @height / 2 > 0 && sy - @height / 2 < Common::SCREEN_Y)   
  end
    
  def draw; end
  
  def update; end
  
  def info; "Object information:\nActor.info: this method needs to be overridden."; end
  
  private :visible?
end

#object with attractive/repulsive force
class Physor < Actor

  #magnitude of Physor (strength of force)
  attr_accessor :mag
  
  def initialize(phys,mag,window)
    super()
    @phys = phys
    @mag = mag
    @window = window
    
    @phys.set_physor(self)
    
    setup_gfx
    setup_sound    
  end
  
  def setup_sound
    @effects = EffectsSystem.new(@window)
    @effects.add_effect(:static,"assets/static.wav")
    @effects.add_effect(:vortex,"assets/vortex.wav")
    
  end
  
  def setup_gfx   
    @image = case @mag <0
             when true 
               Gosu::Image.new(@window,"assets/repulsor.png",false)
             when false 
               Gosu::Image.new(@window, "assets/sphere.png", false) 
           end
            
    @width = @image.width
    @height = @image.height
    set_bounding_box(@width,@height)
  end
   
  def draw(ox,oy)
    #screen coords
    sx = @x-ox
    sy = @y-oy
    
    return if !visible?(sx,sy)
    
    @image.draw_rot(sx, sy, Common::ZOrder::Actor, 0.0) 
  end
  
  def within_range(actor,acc)
    if(!intersect?(actor)):      
      volume = [acc**3,900.0].min/900.0 
      @effects.play_effect(:static,volume)       
    end
  end
  
  def do_collision(collider)
    puts "A #{self.class} of mag #{self.mag} collided with a #{collider.class}"
    if(Projectile === collider): @effects.play_effect(:vortex); end
  end
  
  def info
   "Object information:\nType: #{self.class}; Magnitude: #{@mag}"
  end
  
  private :setup_sound, :setup_gfx
    
end

#Simple interactable object, just for testing purposes
class SampleActor < Actor 

  def initialize(window)   
    super()  
    @window = window
    @hover = 2*Math::PI*rand  
    
    setup_gfx
    setup_sound
  end
  
  def setup_gfx
    @anim = ImageSystem.new(@window)
    @anim.make_animation(:dying,@anim.load_frames("assets/lanternsmoke.png",20,18),0.05,false,false)
    @anim.make_animation(:standard,@anim.load_frames("assets/lanternsmoke.png",20,18)[0],1,false)
    @anim.load_animation(:standard)
    
    image = @anim.get_animation(:standard)[0]
    
    @width = image.width
    @height = image.height
    set_bounding_box(@width,@height)    
  end
  
  def setup_sound
    @effects = EffectsSystem.new(@window)
    @effects.add_effect(:puff,"assets/puff.wav")
  end
  

  def warp(x, y)
    super
    @anchor = @y
    return self
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
    if(!(image=@anim.update)): @expired = true; return; end
            
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
class Projectile  < Actor


  def initialize(window,x,y,angle,vel,direc,owner,world,phys,env) 
    super()
    @window = window
    @x,@y = x,y
    @world = world
    @env = env
    @phys = phys
    
    @owner = owner
    @direc = direc
    

    @init_x = vel * Math::cos((angle / 180) * Math::PI)  #initial velocity for x
    @init_y = vel * Math::sin((angle / 180) * Math::PI)  #initial velocity for y

    setup_gfx
    setup_sound
    setup_vars

  end
  
  def setup_vars
    @t = @orient = 0                                         
    @x_start,@y_start = @x,@y
  end
  
  def setup_gfx
    @image = Gosu::Image.new(@window, "assets/ball.png", false)     
    @width = @image.width
    @height = @image.height
    set_bounding_box(@width,@height)
  end
  
  def setup_sound
    @effects = EffectsSystem.new(@window)
    @effects.add_effect(:bullet,"assets/bullet.wav")
    @effects.add_effect(:vortex,"assets/vortex.wav")
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
  
  def update
      
    check_collision  
    
    #only here to have sound effect when frozen too
    ax = @phys.get_field(self)[0]
    ay = @phys.get_field(self)[1]
    
    #freeze motion
    return if freeze
  
    #time differential
    dt = 0.2
    
    @t = @t + dt

    #space differentials
    dx = ax * @t * dt + @init_x *dt     
    dy = ay * @t * dt - @init_y*dt
    
    #spatial position
    @x+= dx
    @y+= dy
    
    #legal bounds of projectile
    if @y>Common::SCREEN_Y*3 || @y < -Common::SCREEN_Y || @x >Common::SCREEN_X*3 || @x < -Common::SCREEN_X then @expired=true end

  end
       
   def check_collision    
      @world.each do |thing|
      unless thing == self || thing.idle || thing.expired    
         if intersect?(thing):
            case thing
                when Player
               
                else
                    self.do_collision(thing)                                
                    thing.do_collision(self)  
            end
         end
        end
      end
      
      if(tile=@env.check_collision(self)):
        self.do_collision(tile)
        tile.do_collision(self)
      end
    end
    
   def draw(ox,oy)
      #screen coords     
      sx = @x - ox
      sy = @y - oy
      
      return if !visible?(sx,sy)
          
      @orient = (@orient + 3) % 360
      @image.draw_rot(sx, sy, Common::ZOrder::Actor, @orient) 
   end
   
   def info
     "Object information:\nType: #{self.class}; Initial Velocity: #{Math::hypot(@init_x,@init_y)}; Congrats on clicking me ;)"
   end
     
   private :check_collision, :setup_vars, :setup_gfx, :setup_sound
   
 end


# Digger object
class Digger  < Actor
  include Stateology

  def initialize(window,x,y,angle,vel,world,phys,env) 
    super()
    @window = window
    @x,@y = x,y
    @world = world
    @env = env
    @phys = phys
      
    

    @init_x = vel * Math::cos((angle / 180) * Math::PI)  #initial velocity for x
    @init_y = vel * Math::sin((angle / 180) * Math::PI)  #initial velocity for y

    setup_gfx
    setup_sound
    setup_vars

  end
  
  def setup_vars
    @t = 0                                         
    @x_start,@y_start = @x,@y
  end
  
  def setup_gfx
    @image = Gosu::Image.new(@window, "assets/drill.png", false)     
    @width = @image.width
    @height = @image.height
    set_bounding_box(@width,@height)
  end
  
  def setup_sound
    @effects = EffectsSystem.new(@window)
    @effects.add_effect(:bullet,"assets/bullet.wav")
    @effects.add_effect(:drill,"assets/drill.ogg")
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
    #@effects.play_effect(:drill, 0.3)
  end
  
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
        
        # stop digging if selected by mouse
        state Default if freeze
        
        @y = @anchor_y + rand(4)
        
        collide_sound

      end
      
      def state_exit
        @ctile.do_collision(self, 0, @height/2)
        @y = @anchor_y
        @t = 0
      end
    }
       
        
  
  def update
      
    check_collision  
    
    #only here to have sound effect when frozen too
    ax = @phys.grav[0]
    ay = @phys.grav[1]
    
    #freeze motion
    return if freeze
  
    #time differential
    dt = 0.2
    
    @t = @t + dt

    #space differentials
    dx = ax * @t * dt + @init_x * dt     
    dy = ay * @t * dt - @init_y * dt
    
    #spatial position
    @x+= dx
    @y+= dy
    
    #legal bounds of projectile
    if @y>Common::SCREEN_Y*3 || @y < -Common::SCREEN_Y || @x >Common::SCREEN_X*3 || @x < -Common::SCREEN_X then @expired=true end

  end
       
   def check_collision    
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
      
      # we dont want tile collisions if frozen
      return if freeze
      
      if(tile=@env.check_collision(self, 0, @height/2)) then
                
        # when collide with tile, change state to :Digging, maybe put this in the self.do_collision ?
        state Digging, tile
        
        # pretty much no self collision behaviour, all of it occurs in the tile
        self.do_collision(tile)        
      end
    end
    
   def draw(ox,oy)
      #screen coords     
      sx = @x-ox
      sy = @y-oy
      
      return if !visible?(sx,sy)
             
      @image.draw_rot(sx, sy, Common::ZOrder::Actor, 0) 
   end
   
   def info
     "Object information:\nType: #{self.class}"
   end
     
   private :check_collision, :setup_vars, :setup_gfx, :setup_sound
   
 end
    
    
    
    
# Digger object
class Andy  < Actor
  include Stateology

  def initialize(window,x,y,angle,vel,world,phys,env) 
    super()
    @window = window
    @x,@y = x,y
    @world = world
    @env = env
    @phys = phys

    @init_x = vel * Math::cos((angle / 180) * Math::PI)  #initial velocity for x
    @init_y = vel * Math::sin((angle / 180) * Math::PI)  #initial velocity for y

    setup_gfx
    setup_sound
    setup_controls
    setup_vars

  end
  
  def setup_controls
    @controls = { :right => Gosu::Button::KbRight, :left => Gosu::Button::KbLeft,
                :jump => Gosu::Button::KbUp } 
  end
  
  def setup_vars
    @t = 0                                         
    @x_start,@y_start = @x,@y
  end
  
  def setup_gfx
    @image = Gosu::Image.new(@window, "assets/dude.png", false)     
    @width = @image.width
    @height = @image.height
    set_bounding_box(@width,@height)
  end
  
  def setup_sound
    @effects = EffectsSystem.new(@window)
    @effects.add_effect(:bullet,"assets/bullet.wav")
    @effects.add_effect(:drill,"assets/drill.ogg")
  end
  

  def do_collision(collider)
    #super
        
    case collider
      when Projectile, Digger
       # @effects.play_effect(:bullet)
       # @expired = true
        
    end
        
  end
  
  def collide_sound
    @effects.play_effect(:drill, 0.3)
  end
  
  
  
  def update
  
    do_controls { |val| @window.button_down? val}
      
    check_collision  
    
    #only here to have sound effect when frozen too
    #ax = @phys.grav[0]
    #ay = @phys.grav[1]
    
    ax = @phys.get_field(self)[0]
    ay = @phys.get_field(self)[1]
    
    # freeze motion if currently selected by mouse
    return if freeze
    

    
    # if collide with tile on way up then begin descent immediately
    if @env.check_collision(self, 0, -@height/2) then @init_y = 0 end
   
  
    #time differential
    dt = 0.2
    
    @t = @t+dt

    #space differentials
    dx = ax * @t * dt + @init_x * dt     
    dy = ay * @t * dt - @init_y * dt
    
    # don't apply horizontal physics if obstructions to the left or right
    if (!@env.check_collision(self, @width/2, 0) && !@env.check_collision(self, -@width/2, 0)) then
        @x+= dx
        ground_hug 
    end
    
    # dont apply vertical physics if obstructions above or below
    if (!@env.check_collision(self, 0, @height/2) && !@env.check_collision(self, 0, -@height/2)) then
        @y+= dy
    end
    
    
    #legal bounds of Andy
    if @y>Common::SCREEN_Y*3 || @y < -Common::SCREEN_Y || @x >Common::SCREEN_X*3 || @x < -Common::SCREEN_X then 
        puts "Andy fell off the screen and died @ (#{@x.to_i}, #{@y.to_i})"
        @expired = true 
    end

  end
       
   def check_collision    
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
      
      # we dont want tile collisions if frozen
      return if freeze
      
      if(tile=@env.check_collision(self, 0, @height/2)) then
                
        # when collide with tile, reset physics
        @t = 0
        @init_y = 0
        
        # pretty much no self collision behaviour, all of it occurs in the tile
        self.do_collision(tile)        
      end
    end
    
   def draw(ox,oy)
      #screen coords     
      sx = @x-ox
      sy = @y-oy
      
      return if !visible?(sx,sy)
             
      @image.draw_rot(sx, sy, Common::ZOrder::Actor, 0) 
   end
   
   def info
     "Object information:\nType: #{self.class} @ (#{@x.to_i}, #{@y.to_i})"
   end
   
   # ensure Andy follows curve of landscape
   def ground_hug
        prev = @y
        if(@init_y == 0) then
        
            # why 12 ? cos this factor is perfect for climbing steep hills
            # if > 12 unnecessary looping (expensive) if < 12 then can't climb steep hills
            @y-=@height/12              
            begin
                @y+=1 
                
                # if ground is more than 30 pixels away then dont 'hug'; just fall instead
                if (@y - prev) > 30 then
                     @y = prev
                     break
                end
            end until @env.check_collision(self, 0, @height/2)
        end
    end
    
   def do_controls(control_id = nil)
           
        #block-based control keys
        @controls.each_value { |val| if (yield val) then control_id = val; break; end} 

        return self unless control_id   

        # move right if nothing to the right
        if (@controls[:right] == control_id && !@env.check_collision(self, @width/2, 0)) then             
            @x+=5
            ground_hug
        end
            
        # move left if nothing to the left
        if (@controls[:left] == control_id && !@env.check_collision(self, -@width/2, 0)) then             
            @x-=5
            ground_hug
        end
        
        # jump if nothing above, AND currently on the ground (i.e no jumping while in air)
        if (@controls[:jump] == control_id && !@env.check_collision(self, 0, -@height/2) && @env.check_collision(self, 0, @height/2)) then             
            @y-=10
            
            # set an upwards velocity
            @init_y = 60
        end

        return self
  end
     
   private :check_collision, :setup_vars, :setup_gfx, :setup_sound
   
 end
    

