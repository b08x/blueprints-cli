# frozen_string_literal: true

require "ruby_llm/schema"

module BlueprintsCLI
  module Schemas
    # Structured output schema for blueprint name generation.
    # Replaces: `llm_output_adapter type: :single_string, name: 'name'`
    class NameSchema < RubyLLM::Schema
      string :name, description: "A descriptive, title-cased name for this code blueprint (3-6 words)"
    end

    # Structured output schema for blueprint description generation.
    # Replaces: `llm_output_adapter type: :single_string, name: 'description'`
    class DescriptionSchema < RubyLLM::Schema
      string :description,
        description: "A clear, concise description of what this code blueprint accomplishes"
    end

    # Structured output schema for blueprint category generation.
    # Replaces: `llm_output_adapter type: :list_of_strings, name: 'categories'`
    class CategorySchema < RubyLLM::Schema
      array :categories,
        of: :string,
        description: "2-4 relevant category tags for organising this code blueprint"
    end
  end
end
