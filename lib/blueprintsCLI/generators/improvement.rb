# frozen_string_literal: true

module BlueprintsCLI
  module Generators
    # Analyzes a given code blueprint using a Large Language Model (LLM) to suggest
    # specific, actionable improvements across various categories like quality,
    # performance, and security.
    #
    # This generator is designed to provide automated code review feedback, helping
    # developers identify potential issues and adhere to best practices.
    #
    # @example Get improvement suggestions for a Ruby method
    #   code_to_improve = <<-RUBY
    #     def get_user_data(user_id)
    #       data = User.find(user_id)
    #       return data
    #     end
    #   RUBY
    #
    #   generator = BlueprintsCLI::Generators::Improvement.new(
    #     code: code_to_improve,
    #     description: "A simple method to fetch a user record from the database."
    #   )
    #   suggestions = generator.generate
    #   # => [
    #   #   "Refactor the method to handle cases where the user is not found to prevent NilErrors, perhaps by using `find_by` and raising a custom exception.",
    #   #   "Add input validation for `user_id` to ensure it's a valid format before querying the database, preventing potential SQL injection vulnerabilities."
    #   # ]
    class Improvement < Sublayer::Generators::Base
      # Configures the expected LLM output as a list of strings, each representing an improvement.
      llm_output_adapter type: :list_of_strings,
                         name: 'improvements',
                         description: 'Suggested improvements and best practices for this code blueprint'

      # Initializes a new Improvement instance.
      #
      # @param code [String] The source code to be analyzed.
      # @param description [String, nil] An optional high-level description of the code's
      #   functionality to provide more context to the LLM.
      def initialize(code:, description: nil)
        @code = code
        @description = description
      end

      # Executes the code analysis and returns the suggested improvements.
      #
      # This method triggers the base generator's workflow, which involves
      # calling the #prompt method, sending the result to the configured LLM,
      # and parsing the response into a structured list of suggestions.
      #
      # @return [Array<String>] A list of actionable improvement suggestions.
      def generate
        super
      end

      # Constructs the detailed prompt for the LLM.
      #
      # This method assembles the code, its optional description, and a comprehensive
      # set of instructions guiding the LLM to analyze the code across multiple
      # dimensions (e.g., Quality, Performance, Security) and format the output correctly.
      #
      # @return [String] The complete prompt to be sent for analysis.
      def prompt
        <<-PROMPT
          Analyze this code blueprint and suggest specific, actionable improvements.

          #{@description ? "Description: #{@description}" : ''}

          Code:
          ```
          #{@code}
          ```

          Please provide 3-6 specific improvement suggestions focusing on:

          **Code Quality:**
          - Readability and clarity improvements
          - Better variable/method naming
          - Code organization and structure
          - DRY principle violations

          **Performance:**
          - Algorithm efficiency improvements
          - Memory usage optimizations
          - Database query optimizations (if applicable)
          - Caching opportunities

          **Security:**
          - Input validation and sanitization
          - Authentication and authorization concerns
          - Data exposure risks
          - Secure coding practices

          **Best Practices:**
          - Framework-specific conventions
          - Error handling improvements
          - Logging and debugging enhancements
          - Testing considerations

          **Maintainability:**
          - Documentation needs
          - Configuration externalization
          - Dependency management
          - Code modularity

          Format each suggestion as a single, actionable sentence that clearly explains:
          1. WHAT to improve
          2. WHY it's important
          3. HOW to implement it (briefly)

          Focus on the most impactful improvements first. Avoid generic advice.
        PROMPT
      end
    end
  end
end
