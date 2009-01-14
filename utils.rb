
# allows default arguments for attr_accessor
class Module
    def attr_pp(*argv, &block)  

        defaults = {}  

        proxy = Object.new          

        eigen = class << proxy; self; end  

        eigen.send(:define_method, :method_missing) { |name, *argvt|  
            defaults[name] = argvt.size > 1 ? argvt : argvt.first  
        }                      

        proxy.instance_eval(&block)

        defaults.each_pair { |name, default_val|  
            attr_writer(name)  

            define_method(name) do  
                class << self; self; end.class_eval do  
                    attr_reader( name )  
                end  
                if instance_variable_defined? "@#{name}"  
                    instance_variable_get( "@#{name}" )  
                else  
                    instance_variable_set( "@#{name}", default_val )  
                end  
            end  

        }  

        (argv-defaults.keys).each { |name|  
            raise ArgumentError if !(Symbol === name)  

            attr_accessor name  
        }  

    end  
end

class FPSCounter
  attr_reader :fps
  
  def initialize
    @current_second = Gosu::milliseconds / 1000
    @accum_fps = 0
    @fps = 0
  end
  
  def register_tick
    @accum_fps += 1
    current_second = Gosu::milliseconds / 1000
    if current_second != @current_second
      @current_second = current_second
      @fps = @accum_fps
      @accum_fps = 0
    end
  end
end

module HashArgsModule
    def check_args(hash_args, *args)
        if hash_args.first.instance_of?(Hash)
            hash_args = hash_args.first
        else
            raise ArgumentError, "Hash argument expected for #{self.class}"
        end
        
        if (hash_args.keys & args).size != args.size then
            raise ArgumentError, "some required hash keys were missing for #{self.class}"
        end
        hash_args
    end

end
