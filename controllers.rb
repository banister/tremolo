begin
  # In case you use Gosu via RubyGems.
  require 'rubygems'
rescue LoadError
  # In case you don't.
end

require 'gosu' 
require 'common'
 
 
#controls animations and images
class ImageSystem
 
  #internal struct for animation data
  class Anim_struct
    attr_accessor :wait_time, :frames, :loop, :hold
  end
  
  def initialize(window)
    @window=window
    @animations={}
    @frame_counter=0
    @cur_anim=nil
    @timer=0
    @anim={}
    @queue=[]
  end
  
  def load_image(filename)
    return Gosu::Image.new(@window,filename)
  end
  
  def load_frames(filename,frame_width,frame_height)
    return Gosu::Image.load_tiles(@window,filename,frame_width,frame_height,false)
  end
  
  def get_animation(anim_name)
    return @anim[anim_name].frames
  end
  
  def make_animation(anim_name, frame_list, timing,loop=false, hold=true)
    element=Anim_struct.new
    element.wait_time=timing
    element.frames=[*frame_list]
    element.loop=loop
    element.hold=hold
    @anim[anim_name]=element
  end
  
  def load_animation(anim_name)   
    @cur_anim=@anim[anim_name]
    @frame_counter=0
    @timer=Time.now.to_f
    return @anim[anim_name].frames[0]
  end
  
  def load_queue(*args)
    @queue=args     
    if(@queue && !@queue.empty?): load_animation(@queue.shift); end
  end   
  
  def stop
    @queue=[]
    @cur_anim=nil
  end
  
  def restart
    @frame_counter=0
  end
         
  def update()
    return nil if @cur_anim==nil   
    wait_time=@cur_anim.wait_time
    
    if((Time.now.to_f-@timer.to_f) < wait_time): return @cur_anim.frames[@frame_counter]; end
          
      if(@frame_counter < @cur_anim.frames.size-1 && @cur_anim.loop==false) then
        @frame_counter+=1
        @timer=Time.now.to_f
        
        return @cur_anim.frames[@frame_counter]
      elsif(@cur_anim.loop==true) then
        @timer=Time.now.to_f        
        @frame_counter=(1+@frame_counter) % @cur_anim.frames.size
        
        return @cur_anim.frames[@frame_counter]
      else
        if(@queue && !@queue.empty?): load_animation(@queue.shift)
        else return case @cur_anim.hold
                       when true:       
                         @cur_anim.frames[@frame_counter]
                       when false:
                         nil
                    end
        end
      end
           
    end
      
end   

#controls game music
class MusicSystem 
  
  attr_accessor  :loop
  
  def initialize(window) 
    @window=window  
    @play_list={}
    @cur_list_name=nil
    @song_counter=0 
    @loop=false
  end
  
  def load_song(file)        
   
    return Gosu::Song.new(@window,file)    

  end
 
  def make_play_list(name,songs)    
    @play_list[name]=songs        
  end
  
  def load_play_list(list_name)
    if(!@play_list.has_key?(list_name)): return nil; end
    
    @song_counter=0
    @cur_list_name=list_name
    @play_list[list_name][@song_counter].play
  end
  
  def current_song
    @play_list[@cur_list_name].each { |val| return val if val.playing? }
  end
  
  def update
    
    if(!@cur_list_name): return; end
    
    cur_list=@play_list[@cur_list_name]
    if(cur_list[@song_counter].playing?): return; end
    
    if(@loop==false && @song_counter < (cur_list.size-1)):   #subtract 1 because size and max index are off by 1 
       @song_counter+=1 
       cur_list[@song_counter].play
    elsif(@loop==true):
       @song_counter=(@song_counter + 1) % cur_list.size
       cur_list[@song_counter].play
    end
    
  end         
    
 end   
 
  
#controls sound effects
 class EffectsSystem
   def initialize(window)
     @window=window
     @effects={}
   end
   
   def add_effect(key, filename)
     @effects[key]=Gosu::Sample.new(@window, filename)
   end
   
   def play_effect(key,vol=1)
     @effects[key].play(vol)
   end    
   
end

#controls game physics
class PhysicsController

  Grav = 9.81
  
  def initialize
    @physors=[]
  end
  
  def set_physor(p)
  
    #add new physor to the list
    @physors<<p 
  end
  
  def del_physor(p)
  
    #remove a physor from the list
    @physors.delete(p)
  end
  
  def get_field(actor)
    x_acc=0
    y_acc=0
    
    @physors.each do |val|
    
      #direction of vector  
      dx=val.x-actor.x
      dy=val.y-actor.y
      
      #length of vector
      length=Math.hypot(dx, dy)
      
      #normalize vectors
      dx=dx/length
      dy=dy/length
      
      #calculate x and y acceleration
      #not using inverse square law but just inverse 'law', 50 is 'constant of gravitation'
      x_incr=50*(dx*val.mag)/length
      y_incr=50*(dy*val.mag)/length
      
      #sum the vectors to find overall force vector
      x_acc+=x_incr
      y_acc+=y_incr
      
      #magnitude of acceleration vector
      v_mag=Math.hypot(x_incr,y_incr)
      
      #alert physor there is an object within range
      if(length<200 && v_mag > 3): val.within_range(actor,v_mag); end
      
    end
    
    y_acc+=Grav # gravity
    x_acc+=0
    
    return [x_acc,y_acc]
  end
  
  def grav
    [0, Grav]
  end
  
end


  
