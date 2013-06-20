require "minitest/autorun"
require "fileutils"
require "tempfile"
require "timeout"
require "thread"

Dir.chdir(File.dirname(__FILE__))
# for compatibility
Minitest::Test = MiniTest::Unit::TestCase unless defined?(Minitest::Test)

class Rp5Test < Minitest::Test
 # OUTPUT_FILE = File.join(Dir.pwd, "output.txt")

  def test_normal    
    queue = write_and_run_sketch <<EOF
def setup
  size(300, 300)
  frame_rate(10)
end

def draw
  println "ok"
  if frame_count == 10
    exit
  end
end
EOF
    10.times do
      assert_equal "ok", queue.pop
    end
  end

  def test_P2D
    queue = write_and_run_sketch <<EOF
def setup
  size(300, 200, P2D)
end

def draw
  println "ok"
  exit
end
EOF
    assert_equal "ok", queue.pop
  end

  def test_P3D
    queue = write_and_run_sketch <<EOF
def setup
  size(300, 300, P3D)
end

def draw
  println "ok"
  exit
end
EOF
    assert_equal "ok", queue.pop
  end

  
  def test_setup_exception
    queue = write_and_run_sketch <<EOF
def setup
  size(300, 300)
  begin
    unknown_method()
  rescue NoMethodError => e
    println e
  end
end

def draw
end
EOF
    assert queue.pop.index("undefined method `unknown_method'")
  end

  def test_draw_exception
    queue = write_and_run_sketch <<EOF
def setup
  size(300, 300)
end

def draw
  begin 
    unknown_method()
  rescue NoMethodError => e
    println e
  end
end
EOF
    assert queue.pop.index("undefined method `unknown_method'")
  end
  
  def test_opengl_version
    skip("Higher end graphics card could start 4.2")
    queue = write_and_run_sketch <<EOF
def setup
  size(100, 100, P3D)
  puts Java::Processing::opengl::PGraphicsOpenGL.OPENGL_VERSION
end
   
EOF
    assert queue.pop.start_with? '3.3'
  end


  def write_and_run_sketch(sketch_content)
    queue = Queue.new
    Thread.new do
      Tempfile.open("rp5_tester") do |tf|
        tf.write(sketch_content)
        tf.close
        #FileUtils.cp(tf.path, "/tmp/sketch.rb", :verbose => true)
        output = nil
        begin
          Timeout.timeout(15) do 
            open("|../bin/rp5 run #{tf.path}", "r") do |io|
              while l = io.gets
                queue.push(l.chop)
              end
            end
          end
          assert $?.exited?
        rescue Timeout::Error
          assert false, "rp5 timed out"
        end
      end
    end
    return queue
  end
end
