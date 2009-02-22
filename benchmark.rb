# TexPlay test program

begin
    require 'rubygems'
rescue LoadError

end

require 'gosu'
require 'texplay'
require 'benchmark'

class MyWindow < Gosu::Window
    
    # set to true for visible output
    # but note it will interfere with the benchmark
    SHOW = false

    # number of times each benchmark should run
    REPEAT = 1000
    
    def initialize
        super(1024, 768, false, 20)        
        @img = Gosu::Image.new(self,"texplay.png")
        @width = @img.width
        @height = @img.height

        if SHOW then
            class << self
                alias_method :draw, :_draw
            end
        end
    end
  
    def bench_all
        x1 = rand @width
        y1 = rand @height
        x2 = rand @width
        y2 = rand @height
        
        TexPlay.draw(@img) {
            color :random
            circle x1, y1, 10
            line x1, y1, x2, y2 
            box x1, y1, x2 + 100, y2 + 100
            pixel x1, y1
        }
    end

    def bench_clear
        TexPlay.draw(@img) {
            clear
        }
    end

    def bench_circle
        x = rand @width
        y = rand @height
        r = 50
        
        TexPlay.draw(@img) {
            circle x,y, r
        }        
    end
    
    def bench_line
        x1 = rand @width
        y1 = rand @height
        x2 = rand @width
        y2 = rand @height
        
        TexPlay.draw(@img) {
            line x1, y1, x2, y2
        }        
    end    

    def bench_box
        x1 = rand @width
        y1 = rand @height
        x2 = rand @width
        y2 = rand @height
        
        TexPlay.draw(@img) {
            box x1, y1, x2, y2
        }        
    end

    def _draw
        bench_all
        @img.draw(200, 200, 0)
    end

    def do_benchmarks
        Benchmark.bm do |v|
            v.report("all") { REPEAT.times { bench_all } }
            v.report("clear") { REPEAT.times { bench_clear } }
            v.report("circle") { REPEAT.times { bench_circle } }
            v.report("line") { REPEAT.times { bench_line } }
            v.report("box") { REPEAT.times { bench_box } }
        end
    end
end

w = MyWindow.new

if MyWindow::SHOW
    w.show
end

w.do_benchmarks
