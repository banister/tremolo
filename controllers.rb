begin
    require 'rubygems'
rescue LoadError
end

require 'gosu' 
require 'common'

#controls animations and images
class ImageSystem
    
    #internal struct for animation data
    class Anim_struct
        attr_accessor :wait_time, :frames, :loop, :hold
    end

    attr_accessor :facing
    
    def initialize(window, facing=1)
        @window = window
        @animations = {}
        @frame_counter = 0
        @cur_anim = nil
        @timer = 0
        @anim = {}
        @queue = []
        @facing = facing || 1 
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
            @frame_counter += 1
            @timer = Time.now.to_f
            
            return @cur_anim.frames[@frame_counter]
            
        elsif @cur_anim.loop == true then
            @timer = Time.now.to_f        
            @frame_counter = (1 + @frame_counter) % @cur_anim.frames.size
            
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
    Anim = Struct.new(:x, :y, :anim, :zorder, :x_offset, :y_offset, :block)
    
    def initialize
        @group = {}     
    end
    
    def draw(ox,oy)
        
        # iterate and erase
        @group.delete_if { |k, v|
            if nil == v.anim.update then
                
                # run the associated block now that animation has finished
                v.block.call if v.block
                true
            else 
                image = v.anim.update
                facing = v.anim.facing == -1 ? -1 : 1
                
                next if !image

                sx = coordinate(v.x) + v.x_offset - ox
                sy = coordinate(v.y) + v.y_offset - oy

                next if !visible?(sx, sy, image)
                
                image.draw_rot(sx, sy, v.zorder, 0, 0.5, 0.5, facing)
                false
            end
        }
    end

    def coordinate(val)
        
        # Methods are dynamic coordinates
        if val.respond_to?(:call) then
            return val.call
        else
            return val
        end
    end

    #check to see whether object is currently on screen
    def visible?(sx,sy, img)
        (sx + img.width / 2 > 0 && sx - img.width / 2 < Common::SCREEN_X && sy + img.height / 2 > 0 &&
         sy - img.height / 2 < Common::SCREEN_Y)
    end
    
    def new_entry(sym, hash_args, &block)
        g = @group[sym] = Anim.new

        g.x = hash_args[:x]
        g.y = hash_args[:y]
        g.anim = hash_args[:anim]
        g.x_offset = hash_args[:x_offset] || 0
        g.y_offset = hash_args[:y_offset] || 0
        g.zorder = hash_args[:zorder] || Common::ZOrder::Actor

        # save the block
        @group[sym].block = block
        
        @group[sym].anim
    end

    def has_entry?(sym)
        @group.has_key?(sym)
    end

    def remove_entry(sym)
        @group.delete(sym)
    end

    def get_entry(sym)
        @group[sym]
    end

    def get_anim(sym)
        @group[sym].anim if @group[sym]
    end

    def modify_anim(sym, &block)
        if @group[sym] then
            @group[sym].anim.instance_eval(&block)
        end
    end
    private :coordinate, :visible?
end


#timer controller
class TimerSystem

    include HashArgsModule

    TimerStruct = Struct.new(:start_time, :time_out, :action, :repeat)

    def initialize
        @timers = {}
    end

    def register_timer(sym, *hash_args)
        hash_args = check_args(hash_args, :time_out, :action)
        
        @timers[sym] ||= TimerStruct.new

        @timers[sym].start_time = Time.now.to_f
        @timers[sym].time_out = hash_args[:time_out]
        @timers[sym].action = hash_args[:action]
        @timers[sym].repeat = hash_args[:repeat] || false
    end

    def touch(sym)
        @timers[sym].start_time = Time.now.to_f
    end

    def update
        @timers.delete_if do |key, val|
            if (Time.now.to_f - val.start_time) >= val.time_out then
                val.action.call
            
                return !val.repeat
            end
            false
        end
    end

    def exist?(sym)
        !!@timers[sym]
    end

    def unregister_timer(sym)
        @timers.delete(sym)
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
        if !@play_list.has_key?(list_name) then return nil; end
        
        @song_counter = 0
        @cur_list_name = list_name
        @play_list[list_name][@song_counter].play
    end
    
    def current_song
        @play_list[@cur_list_name].each { |val| return val if val.playing? }
    end
    
    def update
        if !@cur_list_name then return; end
        
        cur_list = @play_list[@cur_list_name]
        if cur_list[@song_counter].playing? then return; end
        
        if @loop == false && @song_counter < (cur_list.size - 1) then  #subtract 1 because size and max index are off by 1 
            @song_counter+=1 
            cur_list[@song_counter].play
        elsif @loop == true then
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
            if length < 200 && v_mag > 3 then val.within_range(actor,v_mag); end
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
    
    def do_grav(actor)
        do_physics(actor, false)
    end
end

# Responsible for forwarding events
# to a list of registered listeners
class EventController
    def initialize
        @event_hash = {}
    end

    def register_listener(event_name, lsr)
        @event_hash[event_name] ||= []
        @event_hash[event_name] << lsr
    end

    def method_missing(event_name, *args, &block)
        raise NoMethodError, "No method called #{event_name} registered." if !@event_hash.has_key?(event_name)

        @event_hash[event_name].each { |lsr| lsr.send(event_name, *args, &block) }
    end

    def unregister_listener(event_name, lsr)
        @event_hash[event_name].delete(lsr) if @event_hash[event_name]
    end
end


