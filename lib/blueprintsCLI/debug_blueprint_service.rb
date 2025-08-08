#!/usr/bin/env ruby
# frozen_string_literal: true

# Diagnostic script to debug the blueprint service issues

puts "🔍 Debugging Blueprint Service Issues"
puts "=" * 40

begin
  # Load the environment and models
  puts "Loading environment..."
  require_relative 'config/environment'
  
  puts "Loading models..."
  require_relative 'db/models/blueprint'
  require_relative 'db/models/category'
  
  puts "Loading services..."
  require_relative 'services/blueprint_service'
  
  puts "✅ All modules loaded successfully"
  
rescue => e
  puts "❌ Error loading modules: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

# Test database connection
begin
  puts "\n📊 Testing Database Connection..."
  
  # Check if we can connect to DB
  puts "Database test connection: #{DB.test_connection}"
  
  # Check blueprint count
  blueprint_count = Blueprint.count
  puts "Total blueprints in database: #{blueprint_count}"
  
  # Check category count
  category_count = Category.count
  puts "Total categories in database: #{category_count}"
  
  if blueprint_count > 0
    puts "✅ Database has blueprints"
    
    # Show a sample blueprint
    sample = Blueprint.first
    puts "Sample blueprint: #{sample.name}" if sample
  else
    puts "⚠️  Database is empty - no blueprints found"
  end
  
rescue => e
  puts "❌ Database connection failed: #{e.message}"
  puts e.backtrace.first(3)
end

# Test BlueprintService directly
begin
  puts "\n🔧 Testing BlueprintService..."
  
  service = BlueprintService.new
  puts "BlueprintService instance created successfully"
  
  # Test search without query (should return recent blueprints)
  puts "\nTesting search without query..."
  results = service.search(nil)
  puts "Results returned: #{results.length} blueprints"
  
  if results.length > 0
    puts "✅ Search without query works"
    puts "Sample result keys: #{results.first.keys.join(', ')}" if results.first
  else
    puts "⚠️  No results returned from empty search"
  end
  
  # Test search with query
  puts "\nTesting search with query..."
  query_results = service.search("ruby")
  puts "Query results returned: #{query_results.length} blueprints"
  
rescue => e
  puts "❌ BlueprintService test failed: #{e.message}"
  puts e.backtrace.first(5)
end

# Test RubyLLM integration
begin
  puts "\n🤖 Testing RubyLLM Integration..."
  
  require 'ruby_llm'
  
  # Test embedding generation
  test_text = "test embedding"
  embedding_result = RubyLLM.embed(test_text)
  
  if embedding_result && embedding_result.vectors
    puts "✅ RubyLLM embedding works"
    puts "Embedding vector length: #{embedding_result.vectors.length}"
  else
    puts "⚠️  RubyLLM embedding returned nil or empty"
  end
  
rescue => e
  puts "❌ RubyLLM test failed: #{e.message}"
  puts "This might be expected if RubyLLM is not configured"
end

# Test direct Blueprint.search method
begin
  puts "\n🔎 Testing Blueprint.search directly..."
  
  # Test without query
  direct_results = Blueprint.search(nil).all
  puts "Direct search results: #{direct_results.length}"
  
  # Test with query using fallback
  direct_query_results = Blueprint.search("test").all
  puts "Direct query search results: #{direct_query_results.length}"
  
  puts "✅ Direct Blueprint.search works"
  
rescue => e
  puts "❌ Direct Blueprint.search failed: #{e.message}"
  puts e.backtrace.first(5)
end

puts "\n" + "=" * 40
puts "🏁 Diagnosis Complete"

# Provide recommendations
puts "\n💡 Recommendations:"
if Blueprint.count == 0
  puts "• Database appears to be empty. Add some sample blueprints."
end

puts "• Check database connection configuration"
puts "• Verify RubyLLM is properly configured (this may be optional)"
puts "• Check web server error logs for more details"