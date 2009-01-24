require 'base_classes'


#mouse class
class MousePtr
    include BoundingBox
    include HashArgsModule

    ScrollBorder_x = 200
    ScrollBorder_y = 50
    ScrollSpeed = 12

    #screen coordinates of mouse
    attr_accessor :rx, :ry

    #scrolling variables
    attr_reader :screen_x, :screen_y

    def initialize(window, loglevel, world, env, events)
        @window = window
        @logging_level = loglevel
        @world = world
        @env = env
        @ec = events
        @rot = 0

        setup_pointers
        setup_vars
    end

    def setup_pointers
        @image = ImageSystem.new(@window)
        @image.make_animation(:standard, @image.load_frames("assets/mcrosshair1.png", 67, 67), :timing => 0.02,
                              :loop => true)
        
        @image.make_animation(:on_vehicle, @image.load_frames("assets/mcrosshair2.png", 67, 67)[0])
        
        @image.load_animation(:standard)

        @cur_ptr = @image.cur_anim_name

        #standard size bb
        set_bounding_box(20,20) 
    end

    def setup_vars
        @ec.register_listener(:button_down, self)
        
        #coord vars
        @x = Common::SCREEN_X / 2
        @y = Common::SCREEN_Y / 2
        @rx, @ry = @x, @y
        
        #button logic
        @left_held = false
        @left_pressed = false
        @selec_obj = nil

        #scrolling vars
        @screen_x = 0
        @screen_y = 0
        @no_scroll = false
    end

    def change_pointer(ptr_name)
        @image.load_animation(ptr_name)
        @cur_ptr = ptr_name
    end

    def cur_pointer
        @cur_ptr
    end

    def logging_level
        @logging_level
    end

    #scrolling & ensure mouse isn't in start/asleep state (both y & x==0 at start before first move)
    #variable rate scrolling in proportion to distance to screen edge
    def do_scroll

        #don't scroll if @no_scroll flag is set
        return if @no_scroll

        #x axis
        if @rx <= ScrollBorder_x && (@rx != 0 && @ry != 0) then
            @screen_x -= ScrollSpeed * ((ScrollBorder_x - @rx) / ScrollBorder_x.to_f)
        elsif @rx >= Common::SCREEN_X - ScrollBorder_x then
            @screen_x += ScrollSpeed * ((@rx - (Common::SCREEN_X - ScrollBorder_x)) / ScrollBorder_x.to_f)
        end

        #y axis
        if @ry <= ScrollBorder_y && (@ry != 0 && @ry != 0) then
            @screen_y -= ScrollSpeed * ((ScrollBorder_y - @ry) / ScrollBorder_y.to_f)
        elsif @ry >= Common::SCREEN_Y - ScrollBorder_y then
            @screen_y += ScrollSpeed * ((@ry - (Common::SCREEN_Y - ScrollBorder_y)) / ScrollBorder_y.to_f)
        end
    end

    #manage mouse button presses
    def check_controls

        #remember, button_down() method can also set @left_pressed to true
        #remember, can't always rely on polling to detect button press (reason for use of button_down() method)
        #also remember, below NOT equivalent to @left_pressed=@window...etc; due to potential polling problems.
        @left_pressed = true if @window.button_down?(Gosu::Button::MsLeft)

        #was left mouse button pressed?
        if @left_pressed then

            #button is not currently being held down? (i.e initial press)
            if !@left_held then

                #display information about the object(s) selected
                if(objs=selected) then

                    #select object closest to center of target
                    @selec_obj = objs.inject { |m,c| dist(self,m) < dist(self,c) ? m : c }

                    #tell object its been clicked
                    @selec_obj.left_mouse_click

                else
                    InterfaceElementActor.clear_last_clicked
                end

                #button is currently being held down
            elsif(@left_held && @selec_obj) then

                #seamless transition between tiles
                if @selec_obj.is_a?(Tile) then
                    if (tile=@env.get_tile(self.x, self.y)) != @selec_obj then
                        @selec_obj = tile if tile
                    end
                end
                @selec_obj.left_mouse_held(@x, @y)
            end

            #button press logic
            @left_held = true
            @left_pressed = false

            #button is no longer being pressed, so release the object
        else
            if @selec_obj then  
                #puts "release from @mouse"
                # tell object its been released
                @selec_obj.left_mouse_released
                #puts "sent release msg to #{@selec_obj}"

                #release expired objects for garbage collection (if @selec_obj is only ref to obj)
                @selec_obj = nil
            end

            #button press logic
            @left_held = false
        end

    end

    #distance between 2 Actors
    def dist(o1,o2)
        Math::hypot(o1.x - o2.x, o1.y - o2.y)
    end


    def button_down(id)
        #this is neccesary as sometimes polling doesn't pick up on a button-press
        if id == Gosu::Button::MsLeft then @left_pressed = true; end

        #toggle @no_scroll flag, turns on/off scrolling
        if id == Gosu::Button::MsRight then
            @no_scroll =! @no_scroll
            puts "no scroll is: #{@no_scroll}" if logging_level > 0
        end
    end

    def update

        #update scrolling
        do_scroll

        #buttons clicked?
        check_controls

        #screen coords
        @rx = @window.mouse_x
        @ry = @window.mouse_y

        #actual(game) coords
        @x = @window.mouse_x + screen_x
        @y = @window.mouse_y + screen_y
    end

    def draw
        if @cur_ptr == :on_vehicle then
            @rot = (@rot + 8) % 360
        else
            @rot = 0
        end
        
        @image.update.draw_rot(@rx,@ry,Common::ZOrder::Mouse,@rot)
    end

    #determine game object selected by mouse
    def selected

        things = []

        if tile=@env.get_tile(self.x, self.y) then
            things.push(tile)
        end
        
        @world.each do |thing|
            unless thing == self 
                if intersect?(thing) then
                        things.push(thing)
                end
            end
        end

        return things if !things.empty?
    end

    private :dist, :selected, :check_controls, :do_scroll

end
