# frozen_string_literal: true

require "ruby_llm"
require "ruby_llm/schema"

# Configure RubyLLM from the unified configuration singleton.
# Uses BlueprintsCLI.configuration (already initialised at boot) — no second
# Configuration.new here, which was the bug in the previous sublayer.rb initializer.
RubyLLM.configure do |config|
  config.gemini_api_key    = BlueprintsCLI.configuration.ai_api_key(:gemini)
  config.openai_api_key    = BlueprintsCLI.configuration.ai_api_key(:openai)
  config.anthropic_api_key = BlueprintsCLI.configuration.ai_api_key(:anthropic)
  config.deepseek_api_key  = BlueprintsCLI.configuration.ai_api_key(:deepseek)

  openrouter_key = ENV["OPENROUTER_API_KEY"]
  config.openrouter_api_key = openrouter_key if openrouter_key

  ollama_base = ENV["OLLAMA_API_BASE"]
  config.ollama_api_base = ollama_base if ollama_base

  config.default_model           = BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :default_model,
                                                                      default: "gemini-2.0-flash")
  config.default_embedding_model = BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :default_embedding_model,
                                                                      default: "text-embedding-004")
  config.request_timeout         = BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :request_timeout, default: 120)
  config.max_retries             = BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :max_retries, default: 3)
end
