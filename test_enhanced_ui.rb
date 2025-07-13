#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script for enhanced CLI-UI integration
require_relative 'lib/BlueprintsCLI'

puts "Testing CLI-UI Integration..."

# Test CLI-UI basic functionality
begin
  require 'cli/ui'
  puts "✅ CLI-UI loaded successfully"
rescue LoadError => e
  puts "❌ Failed to load CLI-UI: #{e.message}"
  exit 1
end

# Test BlueprintsCLI integration
begin
  BlueprintsCLI::CLIUIIntegration.initialize!
  puts "✅ CLI-UI integration initialized"
rescue StandardError => e
  puts "❌ Failed to initialize CLI-UI integration: #{e.message}"
  exit 1
end

# Test slash command parser
begin
  parser = BlueprintsCLI::SlashCommandParser.new('/help')
  if parser.valid?
    puts "✅ Slash command parser working"
  else
    puts "❌ Slash command parser validation failed"
  end
rescue StandardError => e
  puts "❌ Slash command parser error: #{e.message}"
end

# Test enhanced menu (basic instantiation)
begin
  menu = BlueprintsCLI::EnhancedMenu.new
  puts "✅ Enhanced menu can be instantiated"
rescue StandardError => e
  puts "❌ Enhanced menu instantiation failed: #{e.message}"
end

# Test autocomplete handler
begin
  handler = BlueprintsCLI::AutocompleteHandler.new
  completions = handler.completions_for('/help')
  puts "✅ Autocomplete handler working (#{completions.size} completions for '/help')"
rescue StandardError => e
  puts "❌ Autocomplete handler error: #{e.message}"
end

puts "\n🎉 CLI-UI integration test completed!"
puts "\nTo test the enhanced menu, run:"
puts "  BLUEPRINTS_ENHANCED_MENU=true bin/blueprintsCLI"
puts "\nTo enable by default, the configuration has been updated in config.yml"