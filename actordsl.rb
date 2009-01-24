#this class provides a DSL for actor creation
class ActorDSL
    include HashArgsModule
    
    def initialize(game_state)
        @gs = game_state
    end

    #this func is not part of DSL interface
    #it is called by GameControl to load the
    #actor_setup* files associated with a theme/level
    #the actor_setup* files are then instance_eval'd in the
    #context of this object, providing a DSL for actor creation
    def load_actors(level, max_x, max_y)
        puts "loading game actors..."

        @max_x = max_x
        @max_y = max_y
        
        theme, map = level.scan(/\d+|\D+/)

        #set path for this theme
        theme_path = "assets/#{theme}/"

        #global for this theme
        if File.exist?("#{theme_path}actor_setup")
            lines = File.read("#{theme_path}actor_setup")
            self.instance_eval(lines)            
        end

        #local to a particular map for this theme
        if File.exist?("#{theme_path}actor_setup#{map}")
            lines = File.read("#{theme_path}actor_setup#{map}")
            self.instance_eval(lines)            
        end        
    end

    # create a single actor
    def create_actor(options={})
        options = {
            :game_state => @gs
        }.merge(options)

        check_args(options, :class, :warp)
        klass = options[:class]
        warp_pos = options[:warp]
        
        actor = klass.new(options)
        actor.warp(*warp_pos)
        @gs.world.push actor
        actor
    end

    #create more than one actor
    #either specify the params in the hash args (options)
    #or spcify the params as args to the _ method in a block
    #advantage in block-form is params are re-evaulated at each call to the block
    #(useful when using rand() for example)
    def create_actors(options={}, &block)
        options = {
            :game_state => @gs
        }.merge(options)
        
        check_args(options, :amount)
        klass = options[:class]
        amount = options[:amount]

        puts "creating #{amount} actors of type #{klass}..." if klass 
        amount.times {

            if block then
                options.merge!(block.call)
                klass = options[:class]
            end
            
            actor = klass.new(options)
            actor.warp(rand(@max_x) + EnvironmentController::Offset_X,
                       rand(300) + EnvironmentController::Offset_Y)
            
            actor.y = 0 if actor.is_a?(Physical)

            @gs.world.push actor
        }
    end

    #randomize all x/y positions of all actors in world
    #physical objects have y set to 0 and only randomized on x
    #so as they just 'drop' into the world
    def randomize_actor_positions
        @gs.world.each { |actor|
            actor.warp(rand(@max_x) + EnvironmentController::Offset_X,
                       rand(300) + EnvironmentController::Offset_Y)
            
            actor.y = 0 if actor.is_a?(Physical)
            
        }
    end

    #special method used to pass arguments in a block
    def _(options={})
        options
    end
end
   
