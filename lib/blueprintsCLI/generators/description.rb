# frozen_string_literal: true

require_relative "../schemas/generator_schemas"
require_relative "../utils/language_detector"

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
    #   description = generator.generate
    #   # => "This Ruby method takes a name as input and returns a greeting string."
    class Description
      # @param code [String] The source code to describe.
      # @param language [String, nil] Override language detection.
      def initialize(code:, language: nil)
        @code     = code
        @language = language || Utils::LanguageDetector.detect(code)
      end

      # Calls the LLM and returns the generated description string.
      #
      # @return [String] The generated blueprint description.
      def generate
        response = RubyLLM.chat(model: model_name)
                          .with_schema(Schemas::DescriptionSchema)
                          .ask(prompt)
        response.content["description"]
      rescue RubyLLM::Error => e
        BlueprintsCLI.logger.failure("Description generation failed: #{e.message}")
        nil
      end

      private

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
