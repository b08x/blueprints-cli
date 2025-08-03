# frozen_string_literal: true

# config/initializers/sublayer.rb

require 'ruby_llm'
require 'sublayer'

# Configure providers lazily when needed, using environment variables as fallback
def self.configure_providers
  blueprints_config = BlueprintsCLI::Configuration.new
  sublayer_config = blueprints_config.sublayer_config
  ruby_llm_config = blueprints_config.ruby_llm_config

  # Configure Sublayer
  Sublayer.configure do |config|
    config.ai_provider = Object.const_get("Sublayer::Providers::#{sublayer_config[:ai_provider]}")
    config.ai_model = sublayer_config[:ai_model]
  end

  # Configure RubyLLM
  unless ruby_llm_config.empty?
    RubyLLM.configure do |config|
      ruby_llm_config.each { |key, value| config.send("#{key}=", value) }
    end
  end

  puts "Sublayer and RubyLLM configured to use #{Sublayer.configuration.ai_provider} with model #{Sublayer.configuration.ai_model}"
rescue StandardError => e
  # Fallback configuration using environment variables
  configure_providers_fallback
  warn "Warning: Using fallback configuration due to error: #{e.message}"
end

def self.configure_providers_fallback
  # Basic Sublayer configuration using environment variables
  Sublayer.configure do |config|
    config.ai_provider = Sublayer::Providers::Gemini
    config.ai_model = ENV.fetch('SUBLAYER_AI_MODEL', 'gemini-2.0-flash')
  end

  # Basic RubyLLM configuration using environment variables
  RubyLLM.configure do |config|
    config.gemini_api_key = ENV['GEMINI_API_KEY'] || ENV.fetch('GOOGLE_API_KEY', nil)
    config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
    config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
    config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)
  end
end

# Only configure if explicitly requested, not during require
configure_providers if ENV['BLUEPRINTS_CONFIGURE_PROVIDERS']
