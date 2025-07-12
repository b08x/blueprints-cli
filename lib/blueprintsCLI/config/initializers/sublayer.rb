# frozen_string_literal: true

# config/initializers/sublayer.rb

require 'ruby_llm'
require 'sublayer'

# Configure Sublayer with your preferred AI provider and model.
# This setup is essential for generating embeddings and other AI-powered features.
Sublayer.configure do |config|
  # This example uses Google Gemini. You can switch to OpenAI or another
  # supported provider by changing the `ai_provider` and `ai_model`.

  # To use OpenAI, you would uncomment these lines:
  # config.ai_provider = Sublayer::Providers::OpenAI
  # config.ai_model = "text-embedding-3-small" # Or another suitable model
  # Make sure to set the OPENAI_API_KEY environment variable.

  # Configuration for Google Gemini
  config.ai_provider = Sublayer::Providers::Gemini
  config.ai_model = 'text-embedding-004' # Recommended model for text embeddings
  # Make sure to set the GEMINI_API_KEY environment variable.
end

# The ruby_llm gem is used for direct embedding generation.
# We configure it to use the same provider and model as Sublayer for consistency.
# This allows service objects to directly call `RubyLLM.embed` without
# needing to know the specific provider details.
RubyLLM.provider = Sublayer.configuration.ai_provider.new(
  model: Sublayer.configuration.ai_model
)

puts "Sublayer and RubyLLM configured to use #{Sublayer.configuration.ai_provider} with model #{Sublayer.configuration.ai_model}"
