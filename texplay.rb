require 'ctexplay'


module TexPlay
    VERSION = "0.1.1"
end

# monkey patching the Gosu::Image class to add image manipulation functionality
module Gosu
    class Image

        # bring in the TexPlay image manipulation methods
        include TexPlay
        
        class << self 
            alias_method :new_prev, :new
            
            def new(*args, &block)

                # invoke old behaviour
                obj = new_prev(*args, &block)

                # refresh the TexPlay image cache
                if obj.width <= 500 && obj.height <= 500 then
                    obj.refresh_cache
                end

                # return the new image
                obj
            end
        end
    end
end
