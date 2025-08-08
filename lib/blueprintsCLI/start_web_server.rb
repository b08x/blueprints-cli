#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple script to start the Falcon/Sinatra web server
require_relative 'web_app'

puts "Starting Blueprints CLI Web Server..."
puts "Access the web interface at: http://localhost:9292"
puts "API endpoints available at: http://localhost:9292/api/"
puts ""
puts "Press Ctrl+C to stop the server"

BlueprintsCLI::WebApp.run!