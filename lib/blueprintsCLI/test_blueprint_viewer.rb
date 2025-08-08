#!/usr/bin/env ruby
# frozen_string_literal: true

# Test for the blueprint viewer fix

puts "🔍 Testing Blueprint Viewer Fix"
puts "=" * 40

require 'net/http'
require 'json'
require 'uri'

def test_blueprint_viewer_flow
  puts "\n📋 Testing Complete Blueprint Viewer Flow..."
  
  begin
    # Step 1: Get list of blueprints
    puts "1. Getting blueprints list..."
    uri = URI('http://localhost:9292/api/blueprints')
    response = Net::HTTP.get_response(uri)
    
    if response.code != '200'
      puts "❌ Failed to get blueprints list: #{response.code}"
      return false
    end
    
    data = JSON.parse(response.body)
    blueprints = data['blueprints'] || []
    
    if blueprints.empty?
      puts "⚠️  No blueprints found in database"
      return false
    end
    
    first_blueprint = blueprints.first
    blueprint_id = first_blueprint['id']
    puts "✅ Found #{blueprints.length} blueprints, testing with ID #{blueprint_id}"
    
    # Step 2: Test individual blueprint API endpoint
    puts "2. Testing individual blueprint API endpoint..."
    uri = URI("http://localhost:9292/api/blueprints/#{blueprint_id}")
    response = Net::HTTP.get_response(uri)
    
    if response.code != '200'
      puts "❌ Failed to get individual blueprint: #{response.code}"
      return false
    end
    
    blueprint = JSON.parse(response.body)
    puts "✅ Individual blueprint API working: '#{blueprint['name']}'"
    
    # Step 3: Test viewer page loading
    puts "3. Testing viewer page loading..."
    uri = URI("http://localhost:9292/viewer?id=#{blueprint_id}")
    response = Net::HTTP.get_response(uri)
    
    if response.code != '200'
      puts "❌ Viewer page failed to load: #{response.code}"
      return false
    end
    
    # Check if page contains expected elements
    html_content = response.body
    expected_elements = [
      'viewer.js',  # JavaScript file included
      'Blueprints CLI',  # Page title
      'blueprint-list-item'  # CSS class for sidebar
    ]
    
    missing_elements = expected_elements.reject { |element| html_content.include?(element) }
    
    if missing_elements.any?
      puts "❌ Viewer page missing elements: #{missing_elements.join(', ')}"
      return false
    end
    
    puts "✅ Viewer page loads correctly with all required elements"
    
    # Step 4: Test static file serving (JavaScript)
    puts "4. Testing JavaScript file serving..."
    uri = URI('http://localhost:9292/js/viewer.js')
    response = Net::HTTP.get_response(uri)
    
    if response.code != '200'
      puts "❌ viewer.js not served correctly: #{response.code}"
      return false
    end
    
    js_content = response.body
    if !js_content.include?('loadBlueprint') || !js_content.include?('updateBlueprintDetails')
      puts "❌ viewer.js missing expected functions"
      return false
    end
    
    puts "✅ viewer.js served correctly with expected functions"
    
    return true
    
  rescue => e
    puts "❌ Test failed with error: #{e.message}"
    return false
  end
end

def test_404_scenarios
  puts "\n🚫 Testing 404 Error Scenarios..."
  
  # Test invalid blueprint ID
  begin
    uri = URI('http://localhost:9292/api/blueprints/99999')
    response = Net::HTTP.get_response(uri)
    
    if response.code == '404'
      puts "✅ Invalid blueprint ID correctly returns 404"
    else
      puts "⚠️  Invalid blueprint ID returns: #{response.code} (expected 404)"
    end
  rescue => e
    puts "❌ Error testing invalid blueprint ID: #{e.message}"
  end
  
  # Test viewer with invalid ID
  begin
    uri = URI('http://localhost:9292/viewer?id=99999')
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      puts "✅ Viewer page loads even with invalid ID (JavaScript will handle the error)"
    else
      puts "❌ Viewer page should load even with invalid ID: #{response.code}"
    end
  rescue => e
    puts "❌ Error testing viewer with invalid ID: #{e.message}"
  end
end

# Run tests
puts "Starting blueprint viewer tests..."

viewer_test_passed = test_blueprint_viewer_flow
test_404_scenarios

puts "\n" + "=" * 40
puts "🏁 Test Results:"

if viewer_test_passed
  puts "✅ ALL VIEWER TESTS PASSED!"
  puts "✅ The 404 error when clicking on blueprints is now FIXED"
  puts ""
  puts "🔧 What was Fixed:"
  puts "   - Missing viewer.html, generator.html, submission.html copied to public/"
  puts "   - Created dynamic viewer.js for blueprint display"
  puts "   - Added getBlueprint(id) method to app.js"
  puts "   - Viewer page now dynamically loads blueprint data"
  puts ""
  puts "🌐 How to Test:"
  puts "   1. Open http://localhost:9292"
  puts "   2. Click on any blueprint card"
  puts "   3. Should navigate to viewer page showing blueprint details"
  puts "   4. No more 404 errors!"
else
  puts "❌ Some tests failed - check the output above"
  puts "   The 404 error may still be present"
end

puts "=" * 40