# frozen_string_literal: true

require_relative "../schemas/generator_schemas"
require_relative "../utils/language_detector"
require 'dry/monads'
require 'json'

module BlueprintsCLI
  module Generators
    # Generates a clear, developer-focused description for a given code snippet.
    #
    # Uses RubyLLM with a structured output schema to guarantee a well-formed
    # single-string description response. Language detection is delegated to
    # Utils::LanguageDetector (which uses Rouge) rather than the deprecated
    # inline regex heuristic.
    #
    # @example
    #   generator = BlueprintsCLI::Generators::Description.new(code: ruby_code)
    #   result = generator.generate
    #   # => Success("This Ruby method takes a name as input and returns a greeting string.")
    class Description
      include Dry::Monads[:result]

      # @param code [String] The source code to describe.
      # @param language [String, nil] Override language detection.
      def initialize(code:, language: nil)
        @code     = code
        @language = language || Utils::LanguageDetector.detect(code)
      end

      # Calls the LLM and returns the generated description string.
      #
      # @return [Dry::Monads::Result] Success(description) or Failure(reason)
      def generate
        BlueprintsCLI.configuration.configure_rubyllm!
        response = RubyLLM.chat(model: model_name)
                          .with_schema(Schemas::DescriptionSchema)
                          .ask(prompt)

        # Handle different response formats from various models
        description = extract_description_from_response(response)
        Success(description)
      rescue RubyLLM::Error => e
        BlueprintsCLI.logger.failure("Description generation failed: #{e.message}")
        Failure(e)
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Unexpected error in description generation: #{e.message}")
        Failure(e)
      end

      private

      # Extract description from response, handling different model response formats
      def extract_description_from_response(response)
        # First try standard content format
        if response.content && response.content.is_a?(Hash) && response.content["description"]
          return response.content["description"]
        end

        # Try reasoning format (GLM models)
        if response.respond_to?(:thinking) && response.thinking&.text
          begin
            parsed = JSON.parse(response.thinking.text)
            return parsed["description"] if parsed["description"]
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
              return parsed["description"] if parsed["description"]
            rescue JSON::ParserError
              # Continue to fallback
            end
          end
        end

        # Ultimate fallback
        "Generated description for this code blueprint."
      end

      def model_name
        BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :default_model,
                                          default: "gemini-2.0-flash")
      end

      def prompt
        <<~PROMPT
          Analyze this #{@language} code and generate a clear, concise description of what it does.

          Code:
          ```#{@language}
          #{@code}
          ```

          Please provide a description that:
          - Explains the primary functionality in 1-2 sentences
          - Mentions key design patterns or techniques used
          - Indicates the intended use case or context
          - Is written for developers who might want to reuse this code

          Focus on WHAT the code does and WHY someone would use it, not HOW it works in detail.
        PROMPT
      end
    end
  end
end
