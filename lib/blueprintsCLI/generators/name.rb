# frozen_string_literal: true

require_relative "../schemas/generator_schemas"

module BlueprintsCLI
  module Generators
    # Generates a descriptive, title-cased name for a given code snippet.
    #
    # Uses RubyLLM with a structured output schema to guarantee a well-formed
    # single-string name response without manual JSON parsing.
    #
    # @example
    #   generator = BlueprintsCLI::Generators::Name.new(code: ruby_code)
    #   name = generator.generate
    #   # => "REST API Response Formatter"
    class Name
      # @param code [String] The source code to generate a name for.
      # @param description [String, nil] Optional existing description for context.
      def initialize(code:, description: nil)
        @code        = code
        @description = description
      end

      # Calls the LLM and returns the generated name string.
      #
      # @return [String] The generated blueprint name.
      def generate
        BlueprintsCLI.configuration.configure_rubyllm!
        response = RubyLLM.chat(model: model_name)
                          .with_schema(Schemas::NameSchema)
                          .ask(prompt)
        response.content["name"]
      rescue RubyLLM::Error => e
        BlueprintsCLI.logger.failure("Name generation failed: #{e.message}")
        nil
      end

      private

      def model_name
        BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :default_model,
                                          default: "gemini-2.0-flash")
      end

      def prompt
        <<~PROMPT
          Generate a clear, descriptive name for this code blueprint.

          #{@description ? "Description: #{@description}" : ""}

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
