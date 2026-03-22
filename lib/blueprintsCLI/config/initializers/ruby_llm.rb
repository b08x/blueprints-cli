# frozen_string_literal: true

require "ruby_llm"
require "ruby_llm/schema"

# Delegates all RubyLLM configuration to the unified Configuration singleton.
# This ensures Rack and CLI boot contexts apply identical settings from config.yml.
BlueprintsCLI.configuration.configure_rubyllm!
