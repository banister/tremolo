require 'rubygems'
require 'stateology'

module InterfaceElementActor
    @@last_clicked = nil
    
    def left_mouse_click
        puts info

        self.freeze = true
        state :Inactive
        
        # keep track of most recently selected Actor
        @@last_clicked = self
    end

    def left_mouse_held(mx, my)
        warp(mx, my)
    end

    def left_mouse_released
        self.freeze = false
        state nil
    end

    def self.clear_last_clicked
        @@last_clicked = nil
    end

    def last_clicked
        @@last_clicked
    end
end

module InterfaceElementTile
    def left_mouse_click
        puts info
    end

    def left_mouse_held(mx, my)
    end

    def left_mouse_released
    end    
end

