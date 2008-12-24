require 'rubygems'
require 'stateology'

# behaviours for mouse interface

# basic interace for Actors
module InterfaceElementActor
    @@last_clicked = nil
    
    def left_mouse_click
        puts info

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
            if add_driver(last_clicked) then
                last_clicked.entered_vehicle(self)
            end
        end

        super
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

        new_anim.make_animation(:standard, new_anim.load_image("assets/arrow.png"), :timing => 1)

        new_anim.load_animation(:standard)
    end


    alias_method :button_down, :do_controls
end
#################### End InterfaceElementControllable ##################


# interface for Actors that are both Vehicles and Controllable
module InterfaceElementControllableVehicle
    include InterfaceElementControllable
    include InterfaceElementVehicle

    def left_mouse_released
        if has_driver? then
            state :Controllable
        else
            state nil
        end
    end
end

# interface for Tiles
module InterfaceElementTile
    def left_mouse_click
        puts info
    end

    def left_mouse_held(mx, my)
    end

    def left_mouse_released
    end    
end

