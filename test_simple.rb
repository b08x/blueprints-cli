# Simple test code for blueprint submission
class SimpleTest
  def initialize(name)
    @name = name
  end
  
  def greet
    puts "Hello, #{@name}\! This is a simple test class."
  end
  
  def demonstrate_features
    greet
    puts "Features: #{calculate_features}"
  end
  
  private
  
  def calculate_features
    features = ['initialization', 'greeting', 'private methods']
    features.join(', ')
  end
end

# Usage example
test = SimpleTest.new("Ruby Developer")
test.demonstrate_features
EOF < /dev/null