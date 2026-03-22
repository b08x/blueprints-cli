# frozen_string_literal: true

require "ruby_llm"
require "ruby_llm/schema"

# Configure RubyLLM using environment variables directly to avoid circular
# dependency during configuration loading. This initializer runs in Rack context;
# CLI context uses configuration.rb's configure_rubyllm method instead.
RubyLLM.configure do |config|
  config.gemini_api_key    = ENV["GEMINI_API_KEY"] || ENV.fetch("GOOGLE_API_KEY", nil)
  config.openai_api_key    = ENV["OPENROUTER_API_KEY"] || ENV.fetch("OPENAI_API_KEY", nil)
  config.anthropic_api_key = ENV.fetch("ANTHROPIC_API_KEY", nil)
  config.deepseek_api_key  = ENV.fetch("DEEPSEEK_API_KEY", nil)

  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"] if ENV["OPENROUTER_API_KEY"]
  config.ollama_api_base    = ENV["OLLAMA_API_BASE"] if ENV["OLLAMA_API_BASE"]

  config.default_model           = ENV.fetch("RUBYLLM_DEFAULT_MODEL", "gemini-2.0-flash")
  config.default_embedding_model = ENV.fetch("RUBYLLM_EMBEDDING_MODEL", "embeddinggemma")
  config.request_timeout         = ENV.fetch("RUBYLLM_REQUEST_TIMEOUT", "120").to_i
  config.max_retries             = ENV.fetch("RUBYLLM_MAX_RETRIES", "3").to_i
end
