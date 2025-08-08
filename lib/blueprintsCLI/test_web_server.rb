#!/usr/bin/env ruby
# frozen_string_literal: true

# Integration test script for the Falcon/Sinatra web UI

require 'net/http'
require 'json'

puts "🚀 Starting Blueprints CLI Web Server Integration Tests"
puts "=" * 50

# Start the web server in background
puts "Starting web server..."
server_pid = spawn('ruby start_web_server.rb > /dev/null 2>&1')
sleep 3  # Give server time to start

# Test configuration
BASE_URL = 'http://localhost:9292'
tests_passed = 0
tests_total = 0

def test(description)
  print "Testing #{description}... "
  tests_total = $tests_total = ($tests_total || 0) + 1
  begin
    result = yield
    if result
      puts "✅ PASS"
      $tests_passed = ($tests_passed || 0) + 1
    else
      puts "❌ FAIL"
    end
  rescue => e
    puts "❌ ERROR: #{e.message}"
  end
end

# Test 1: Health Check
test("API health endpoint") do
  uri = URI("#{BASE_URL}/api/health")
  response = Net::HTTP.get_response(uri)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    data['status'] == 'ok'
  else
    false
  end
end

# Test 2: Static File Serving
test("HTML page serving") do
  uri = URI("#{BASE_URL}/")
  response = Net::HTTP.get_response(uri)
  response.code == '200' && response.content_type.include?('text/html')
end

test("CSS file serving") do
  uri = URI("#{BASE_URL}/css/app.css")
  response = Net::HTTP.get_response(uri)
  response.code == '200' && response.content_type.include?('text/css')
end

test("JavaScript file serving") do
  uri = URI("#{BASE_URL}/js/app.js")
  response = Net::HTTP.get_response(uri)
  response.code == '200' && response.content_type.include?('javascript')
end

# Test 3: API Endpoints
test("blueprints listing") do
  uri = URI("#{BASE_URL}/api/blueprints")
  response = Net::HTTP.get_response(uri)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    data.is_a?(Hash) && data['blueprints'].is_a?(Array)
  else
    false
  end
end

test("code generation API") do
  uri = URI("#{BASE_URL}/api/blueprints/generate")
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = {
    prompt: "Create a simple function",
    language: "javascript"
  }.to_json
  
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    data.is_a?(Hash) && data.key?('code')
  else
    false
  end
end

test("metadata generation API") do
  uri = URI("#{BASE_URL}/api/blueprints/metadata")
  http = Net::HTTP.new(uri.host, uri.port)
  
  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request.body = {
    code: "function hello() { return 'world'; }"
  }.to_json
  
  response = http.request(request)
  
  if response.code == '200'
    data = JSON.parse(response.body)
    data.is_a?(Hash) && data.key?('name')
  else
    false
  end
end

# Test 4: CORS Headers
test("CORS headers") do
  uri = URI("#{BASE_URL}/api/health")
  response = Net::HTTP.get_response(uri)
  response['Access-Control-Allow-Origin'] == '*'
end

# Test 5: Error Handling
test("404 error handling") do
  uri = URI("#{BASE_URL}/nonexistent")
  response = Net::HTTP.get_response(uri)
  response.code == '404'
end

# Cleanup
puts "\n" + "=" * 50
puts "🧹 Cleaning up..."
Process.kill('TERM', server_pid) rescue nil
Process.wait(server_pid) rescue nil

# Results
puts "📊 Test Results:"
puts "   Tests Passed: #{$tests_passed || 0}/#{$tests_total || 0}"
puts "   Success Rate: #{($tests_passed || 0) * 100 / ($tests_total || 1)}%"

if ($tests_passed || 0) == ($tests_total || 0)
  puts "🎉 All tests passed! Web server is working correctly."
  exit 0
else
  puts "⚠️  Some tests failed. Please check the implementation."
  exit 1
end