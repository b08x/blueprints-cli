# frozen_string_literal: true

require_relative "../schemas/generator_schemas"
require "dry/monads"
require "json"

module BlueprintsCLI
  module Generators
    # Generates a descriptive, title-cased name for a given code snippet.
    #
    # Uses RubyLLM with a structured output schema to guarantee a well-formed
    # single-string name response without manual JSON parsing.
    #
    # @example
    #   generator = BlueprintsCLI::Generators::Name.new(code: ruby_code)
    #   result = generator.generate
    #   # => Success("REST API Response Formatter")
    class Name
      include Dry::Monads[:result]

      # @param code [String] The source code to generate a name for.
      # @param description [String, nil] Optional existing description for context.
      def initialize(code:, description: nil)
        @code        = code
        @description = description
      end

      # Calls the LLM and returns the generated name string wrapped in a Result.
      #
      # @return [Dry::Monads::Result] Success(name) or Failure(reason)
      def generate
        BlueprintsCLI.configuration.configure_rubyllm!
        response = RubyLLM.chat(model: model_name)
          .with_schema(Schemas::NameSchema)
          .ask(prompt)

        # Handle different response formats from various models
        name = extract_name_from_response(response)
        Success(name)
      rescue RubyLLM::Error => e
        BlueprintsCLI.logger.failure("Name generation failed: #{e.message}")
        Failure(e)
      rescue => e
        BlueprintsCLI.logger.failure("Unexpected error in name generation: #{e.message}")
        Failure(e)
      end

      private def model_name
        BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :default_model,
          default: "gemini-2.0-flash")
      end

      # Extract name from response, handling different model response formats
      private def extract_name_from_response(response)
        # First try standard content format
        return response.content["name"] if response.content && response.content.is_a?(Hash) && response.content["name"]

        # Try reasoning format (GLM models)
        if response.respond_to?(:thinking) && response.thinking&.text
          begin
            parsed = JSON.parse(response.thinking.text)
            return parsed["name"] if parsed["name"]
          rescue JSON::ParserError
            # Fall back to content if JSON parsing fails
          end
        end

        # Fallback: try to extract from raw response
        if response.respond_to?(:raw) && response.raw.respond_to?(:body)
          body = response.raw.body
          if body.is_a?(Hash) && body.dig("choices", 0, "message", "reasoning")
            begin
              reasoning_text = body.dig("choices", 0, "message", "reasoning")
              parsed = JSON.parse(reasoning_text)
              return parsed["name"] if parsed["name"]
            rescue JSON::ParserError
              # Continue to fallback
            end
          end
        end

        # Ultimate fallback
        "Generated Blueprint Name"
      end

      private def prompt
        <<~PROMPT
          Generate a clear, descriptive name for this code blueprint.

          #{"Description: #{@description}" if @description}

          Code:
          ```
          #{@code}
          ```

          The name should:
          - Be 3-6 words long
          - Clearly indicate what the code does
          - Use title case (e.g., "User Authentication Helper", "CSV Data Processor")
          - Be specific enough to distinguish it from similar code
          - Avoid generic terms like "Script" or "Code" unless necessary

          Examples of good names:
          - "REST API Response Formatter"
          - "Database Migration Helper"
          - "Email Template Generator"
          - "JWT Token Validator"
          - "File Upload Handler"
        PROMPT
      end
    end
  end
end
