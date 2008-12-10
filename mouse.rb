require 'base_classes'


#mouse class
class MousePtr
    include BoundingBox

    #screen coordinates of mouse
    attr_accessor :rx, :ry

    #scrolling variables

    attr_reader :screen_x, :screen_y

    def initialize(window,world,env)
        @window = window
        @world = world
        @env = env
        @image = Gosu::Image.load_tiles(@window,"assets/crosshair.png",67,67,false)[0]
        @x = Common::SCREEN_X / 2
        @y = Common::SCREEN_Y / 2
        @rx,@ry = @x,@y
        @left_held = false
        @left_pressed = false
        @selec_obj = nil

        #scrolling vars
        @screen_x = 0
        @screen_y = 0
        @scroll_border_x = 200
        @scroll_border_y = 50
        @scroll_speed = 12
        @no_scroll = false

        #standard size bb
        set_bounding_box(50,50)
    end

    #scrolling & ensure mouse isn't in start/asleep state (both y & x==0 at start before first move)
    #variable rate scrolling in proportion to distance to screen edge
    def do_scroll

        #don't scroll if @no_scroll flag is set
        return if @no_scroll

        #x axis
        if @rx <= @scroll_border_x && (@rx != 0 && @ry != 0) then
            @screen_x -= @scroll_speed * ((@scroll_border_x - @rx) / @scroll_border_x.to_f)
        elsif @rx >= Common::SCREEN_X - @scroll_border_x then
            @screen_x += @scroll_speed * ((@rx - (Common::SCREEN_X - @scroll_border_x)) / @scroll_border_x.to_f)
        end

        #y axis
        if @ry <= @scroll_border_y && (@ry != 0 && @ry != 0) then
            @screen_y -= @scroll_speed * ((@scroll_border_y - @ry) / @scroll_border_y.to_f)
        elsif @ry >= Common::SCREEN_Y - @scroll_border_y then
            @screen_y += @scroll_speed * ((@ry-(Common::SCREEN_Y-@scroll_border_y)) / @scroll_border_y.to_f)
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

                    # tell object its been clicked
                    @selec_obj.left_mouse_click

                    #is it an Actor? exclude non-actors from drag & drop
                    @selec_obj = nil if !(Actor === @selec_obj)
                else
                    InterfaceElementActor.clear_last_clicked

                end

                #button is currently being held down, so try to 'drag' the object around.
            elsif(@left_held && @selec_obj) then

                    # alert object it's being held
                    @selec_obj.left_mouse_held(@x, @y)


                #release object if it's expired
                if @selec_obj.expired then
                    @selec_obj = nil     
                    @left_held = false
                end

            end

            #button press logic
            @left_held = true
            @left_pressed = false

            #button is no longer being pressed, so release the object
        else
            if @selec_obj then  
                
                # tell object its been released
                @selec_obj.left_mouse_released

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
        if id == Gosu::Button::MsRight then @no_scroll =! @no_scroll; puts "no scroll is: #{@no_scroll}"; end
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
        @image.draw_rot(@rx,@ry,Common::ZOrder::Mouse,0.0)
    end

    #determine game object selected by mouse
    def selected
        things = []
        @world.each do |thing|
            unless thing == self || thing.idle || thing.expired
                if intersect?(thing) then
                        things.push(thing)
                end
            end
        end

        if tile=@env.check_collision(self) then
                things.push(tile)
        end

        return things if !things.empty?
    end

    private :dist, :selected, :check_controls, :do_scroll

end
