# frozen_string_literal: true

# config/initializers/sublayer.rb

require 'ruby_llm'
require 'sublayer'

# Configure Sublayer using the unified configuration system
blueprints_config = BlueprintsCLI::Configuration.new
sublayer_config = blueprints_config.sublayer_config

Sublayer.configure do |config|
  config.ai_provider = Object.const_get("Sublayer::Providers::#{sublayer_config[:ai_provider]}")
  config.ai_model = sublayer_config[:ai_model]
end

# Configure RubyLLM using the unified configuration system
ruby_llm_config = blueprints_config.ruby_llm_config
unless ruby_llm_config.empty?
  RubyLLM.configure do |config|
    ruby_llm_config.each { |key, value| config.send("#{key}=", value) }
  end
end

# Set up RubyLLM provider to match Sublayer for consistency
begin
  RubyLLM.provider = Sublayer.configuration.ai_provider.new(
    model: Sublayer.configuration.ai_model
  )
rescue StandardError => e
  # Continue without RubyLLM provider setup if it fails
  puts "Warning: Could not set up RubyLLM provider: #{e.message}"
end

puts "Sublayer and RubyLLM configured to use #{Sublayer.configuration.ai_provider} with model #{Sublayer.configuration.ai_model}"
