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
        @window = window
        @animations = {}
        @frame_counter = 0
        @cur_anim = nil
        @timer = 0
        @anim = {}
        @queue = []
    end
    
    def load_image(filename)
        return Gosu::Image.new(@window,filename)
    end
    
    def load_frames(filename,frame_width,frame_height)
        return Gosu::Image.load_tiles(@window,filename,frame_width,frame_height,false)
    end
    
    def self.load_image(filename)
        return Gosu::Image.new(@window,filename)
    end
    
    def self.load_frames(filename,frame_width,frame_height)
        return Gosu::Image.load_tiles(@window,filename,frame_width,frame_height,false)
    end
    
    
    def get_animation(anim_name)
        return @anim[anim_name].frames
    end
    
    def make_animation(anim_name, frame_list, hash_args)

        # default args (taking into account 'false' is a valid arg)
        timing = hash_args[:timing].nil? ? 1 : hash_args[:timing] 
        loop = hash_args[:loop].nil? ? false : hash_args[:loop] 
        hold = hash_args[:hold].nil? ? true : hash_args[:hold]
        
        element = Anim_struct.new
        element.wait_time = timing
        element.frames = [*frame_list]
        element.loop = loop
        element.hold = hold
        @anim[anim_name] = element
    end
    
    def load_animation(anim_name)   
        @cur_anim = @anim[anim_name]
        @frame_counter = 0
        @timer = Time.now.to_f
        return @anim[anim_name].frames[0]
    end
    
    def load_queue(*args)
        @queue = args     
        if @queue && !@queue.empty? then load_animation(@queue.shift); end
    end   
    
    def stop
        @queue = []
        @cur_anim = nil
    end
    
    def restart
        @frame_counter = 0
    end
    
    def update
        return nil if @cur_anim == nil   
        wait_time = @cur_anim.wait_time
        
        if (Time.now.to_f - @timer.to_f) < wait_time then return @cur_anim.frames[@frame_counter]; end
        
        if @frame_counter < @cur_anim.frames.size - 1 && @cur_anim.loop == false then
            @frame_counter+=1
            @timer = Time.now.to_f
            
            return @cur_anim.frames[@frame_counter]
            
        elsif @cur_anim.loop == true then
            @timer = Time.now.to_f        
            @frame_counter = ( 1 + @frame_counter) % @cur_anim.frames.size
            
            return @cur_anim.frames[@frame_counter]
        else
            if @queue && !@queue.empty? then 
                load_animation(@queue.shift)
            else 
                return case @cur_anim.hold
                       when true:       
                               @cur_anim.frames[@frame_counter]
                       when false:
                               nil
                       end
            end
        end
        
    end
    
end   

# Manages group of animations usually associated with a game object
# e.g explosions associated with a tank or with a tile etc
# Responsible for updating the frames and removing animations from list
# when finished.
class AnimGroup

    # block is executed when animation is finished
    # block behaves a bit like a destructor
    Anim = Struct.new(:x, :y, :anim, :zorder, :block)
    
    def initialize
        @group = []     
    end
    
    def draw(ox,oy)
        
        # iterate and erase
        @group.delete_if { |v|
            if nil == v.anim.update then
                
                # run the associated block now that animation has finished
                v.block.call if v.block
                true
            else 
                misc_image = v.anim.update 
                
                next if !misc_image
                
                misc_image.draw_rot(v.x - ox, v.y - oy, v.zorder, 0)
                false
            end
        }
    end
    
    def new_entry(*args, &block)
        @group << Anim.new(*args)
        
        # if zorder parameter is NOT supplied then default
        @group.last.zorder = Common::ZOrder::Actor if !args[3] 
        
        # save the block
        @group.last.block = block
        
        @group.last
    end
    
    def <<(anim)
        @group << anim
    end
end


#controls game music
class MusicSystem 
    
    attr_accessor  :loop
    
    def initialize(window) 
        @window = window  
        @play_list = {}
        @cur_list_name = nil
        @song_counter = 0 
        @loop = false
    end
    
    def load_song(file)        
        
        return Gosu::Song.new(@window,file)    

    end
    
    def make_play_list(name,songs)    
        @play_list[name] = songs        
    end
    
    def load_play_list(list_name)
        if(!@play_list.has_key?(list_name)) then return nil; end
        
        @song_counter = 0
        @cur_list_name = list_name
        @play_list[list_name][@song_counter].play
    end
    
    def current_song
        @play_list[@cur_list_name].each { |val| return val if val.playing? }
    end
    
    def update
        
        if(!@cur_list_name) then return; end
        
        cur_list = @play_list[@cur_list_name]
        if(cur_list[@song_counter].playing?) then return; end
        
        if(@loop == false && @song_counter < (cur_list.size - 1)) then  #subtract 1 because size and max index are off by 1 
            @song_counter+=1 
            cur_list[@song_counter].play
        elsif(@loop == true) then
            @song_counter = (@song_counter + 1) % cur_list.size
            cur_list[@song_counter].play
        end
        
    end     

 
    
end   


#controls sound effects
class EffectsSystem
    def initialize(window)
        @window = window
        @effects = {}
    end
    
    def add_effect(key, filename)
        @effects[key] = Gosu::Sample.new(@window, filename)
    end
    
    def play_effect(key,vol=1)
        @effects[key].play(vol)
    end    
    
end

#controls game physics
class PhysicsController

    Grav = 9.81
    
    Time_tick = 0.2
    
    # == 2 for inverse square law
    INVERSE_LAW = 1
    
    def initialize
        @physors = []
    end
    
    def set_physor(p)
        
        #add new physor to the list
        @physors << p 
    end
    
    def del_physor(p)
        
        #remove a physor from the list
        @physors.delete(p)
    end
    
    def get_field(actor)
        x_acc = 0
        y_acc = 0
        
        @physors.each do |val|
            
            #direction of vector  
            dx = val.x - actor.x
            dy = val.y - actor.y
            
            #length of vector
            length = Math.hypot(dx, dy)
            
            #normalize vectors
            dx = dx / length
            dy = dy / length
            
            #calculate x and y acceleration
            #not using inverse square law but just inverse 'law', 50 is 'constant of gravitation'
            x_incr = 50 * (dx * val.mag) / length ** INVERSE_LAW
            y_incr = 50 * (dy * val.mag) / length ** INVERSE_LAW
            
            #sum the vectors to find overall force vector
            x_acc += x_incr
            y_acc += y_incr
            
            #magnitude of acceleration vector
            v_mag = Math.hypot(x_incr,y_incr)
            
            #alert physor there is an object within range
            if(length < 200 && v_mag > 3) then val.within_range(actor,v_mag); end
            
        end
        
        y_acc += Grav # gravity
        x_acc += 0
        
        return [x_acc,y_acc]
    end

    def do_physics(actor, field = true)

        if !actor.phys_info[:physical] then
            return [actor.x, actor.y]
        end
        
        # acceleration
        ax, ay = actor.phys_info[:gravity_only] ? [0, Grav] : get_field(actor) 
        
        # velocity differentials
        dx = ax * actor.time * Time_tick + actor.init_x * Time_tick
        dy = ay * actor.time * Time_tick - actor.init_y * Time_tick

        # update spatial displacement
        x = actor.x + dx
        y = actor.y + dy

        actor.time += Time_tick
        
        [x, y]

    end

    def reset_physics(actor)
        actor.time = 0
    end
    
    def do_grav
        do_physics(false)
    end
    
end



