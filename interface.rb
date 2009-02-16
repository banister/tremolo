require 'rubygems'
require 'stateology'

# basic interace for Actors
module InterfaceElementActor
    @@last_clicked = nil
    
    def left_mouse_click
        puts info if logging_level > 0

        state :Inactive
        
        if last_clicked && last_clicked != self then
            last_clicked.unclicked
        end
        @@last_clicked = self
    end

    def left_mouse_held(mx, my)
        warp(mx, my)
    end

    def left_mouse_released
        state nil
    end

    def unclicked
    end

    def self.clear_last_clicked
        @@last_clicked.unclicked if @@last_clicked
        @@last_clicked = nil
    end

    def last_clicked=(lc)
        @@last_clicked = lc
    end

    def last_clicked
        @@last_clicked
    end

    def last_clicked?(lc)
        @@last_clicked == lc
    end
end


# interface for Actors that are Vehicles
module InterfaceElementVehicle
    include InterfaceElementActor
    
    def left_mouse_click

        if  last_clicked.kind_of?(Andy) && actor_collision_with?(last_clicked) then
             add_driver(last_clicked)            
        end

        if last_clicked == self then
            @_saved_coords = [@x.to_i, @y.to_i]
        end

        super
    end

    def left_mouse_released
        #puts "saved coords release: #{_saved_coords}"
        if @_saved_coords && @_saved_coords == [@x.to_i, @y.to_i] then
            remove_driver
        end
        state nil
    end
end

# interface for Actors that can be controlled by keyboard
module InterfaceElementControllable
    include InterfaceElementActor
    
    def unclicked
        unregister_animation(:arrow)
        state nil
    end

    def left_mouse_click
        super

        create_arrow

            
    end

    def left_mouse_released
        state :Controllable 
    end


    def do_controls(*args, &block)
        #this should be left empty
        #as we want no behaviour outside
        #of the Controllable state
    end

    def create_arrow
        hover = 2 * Math::PI * rand
        dy = 0
        y_float = lambda do
            hover = hover + 0.1 % (2 * Math::PI)
            dy = 10 * Math::sin(hover)
            method(:y).call + dy
        end

        new_anim = register_animation(:arrow, :x => method(:x), :y => y_float, :x_offset => 0, :y_offset => -80,
                                      :zorder => Common::ZOrder::Interface)

        new_anim.make_animation(:standard, new_anim.load_image("assets/arrow.png"))

        new_anim.load_animation(:standard)
    end


    alias_method :button_down, :do_controls
end
#################### End InterfaceElementControllable ##################


# interface for Actors that are both Vehicles and Controllable
module InterfaceElementControllableVehicle
    include InterfaceElementVehicle

    def left_mouse_released
        super
        
        if has_driver? then
            state :Controllable
        else
            state nil
        end
    end

    def do_controls(*args, &block)
    end
    alias_method :button_down, :do_controls

end

# interface for Tiles
module InterfaceElementTile
    def left_mouse_click
        puts info if logging_level > 0
    end

    def left_mouse_held(mx, my)
        xp = mx - self.x
        yp = my - self.y

        TexPlay.draw(@image) {
            color :random
            circle xp, yp, 10
        }
    end

    def left_mouse_released
    end    
end

