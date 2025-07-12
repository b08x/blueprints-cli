# frozen_string_literal: true

module BlueprintsCLI
  module Generators
    #
    # Generates a descriptive, title-cased name for a given code snippet,
    # referred to as a "code blueprint".
    #
    # This class constructs a detailed prompt for an LLM, providing the code,
    # an optional description, and specific rules to guide the model in creating
    # a suitable name. It is designed to produce names that are 3-6 words long,
    # clearly indicate functionality, and are specific enough to be useful in a
    # catalog of blueprints.
    #
    class Name < Sublayer::Generators::Base
      llm_output_adapter type: :single_string,
                         name: 'name',
                         description: 'A descriptive name for this code blueprint'

      #
      # Initializes a new instance of the Name.
      #
      # @param code [String] The source code of the blueprint for which to generate a name.
      # @param description [String, nil] An optional existing description of the code to
      #   provide additional context for the name generation process.
      #
      def initialize(code:, description: nil)
        @code = code
        @description = description
      end

      #
      # Executes the name generation process.
      #
      # This method delegates to the parent class's `generate` method, which is
      # responsible for orchestrating the call to the LLM with the prompt from
      # the `#prompt` method and returning the resulting name.
      #
      # @return [String] The generated name for the code blueprint.
      #
      def generate
        super
      end

      #
      # Constructs the prompt sent to the LLM for name generation.
      #
      # The prompt includes the code, an optional description, and a set of rules
      # and examples to guide the LLM in creating a high-quality, formatted name.
      # It specifically requests a title-cased name that is 3-6 words long and
      # avoids generic terms.
      #
      # @return [String] The complete, formatted prompt text.
      #
      def prompt
        <<-PROMPT
          Generate a clear, descriptive name for this code blueprint.

          #{@description ? "Description: #{@description}" : ''}

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

          Return only the name, no additional text or explanation.
        PROMPT
      end
    end
  end
end
