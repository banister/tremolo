require 'rubygems'
require 'stateology'

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

