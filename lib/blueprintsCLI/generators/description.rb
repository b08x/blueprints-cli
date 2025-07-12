# frozen_string_literal: true

module BlueprintsCLI
  module Generators
    #
    # Uses a Large Language Model (LLM) to generate a clear, developer-focused
    # description for a given snippet of source code.
    #
    # This generator analyzes the provided code, automatically detects its
    # programming language if not specified, and produces a concise summary.
    # It is designed to create documentation for "code blueprints" that can be
    # reused by other developers.
    #
    # The output is configured via `llm_output_adapter` to be a single string
    # containing the generated description.
    #
    # @example Generating a description for a Ruby method
    #   ruby_code = "def hello(name)\n  \"Hello, \#{name}!\"\nend"
    #   generator = BlueprintsCLI::Generators::Description.new(code: ruby_code)
    #   description = generator.generate
    #   # => "This Ruby method `hello` takes a name as input and returns a greeting string."
    #
    class Description < Sublayer::Generators::Base
      llm_output_adapter type: :single_string,
                         name: 'description',
                         description: 'A clear, concise description of what this code blueprint accomplishes'

      #
      # Initializes a new blueprint description generator.
      #
      # It prepares the generator with the necessary code and determines the
      # programming language, which is crucial for crafting an accurate LLM prompt.
      #
      # @param code [String] The source code to be analyzed and described.
      # @param language [String, nil] The programming language of the code. If `nil`,
      #   the language is automatically detected using `#detect_language`.
      #
      def initialize(code:, language: nil)
        @code = code
        @language = language || detect_language(code)
      end

      #
      # Executes the LLM call to generate the code description.
      #
      # This method delegates to the `super` method from `Sublayer::Generators::Base`,
      # which handles the core logic of sending the prompt (from the `#prompt` method)
      # to the LLM and parsing the response.
      #
      # @return [String] A clear, concise description of the code's functionality.
      #
      def generate
        super
      end

      #
      # Constructs the prompt that instructs the LLM on how to generate the description.
      #
      # The prompt includes the source code, its detected language, and specific
      # guidelines for creating a high-quality, developer-oriented summary.
      #
      # @return [String] The fully-formed prompt to be sent to the LLM.
      #
      def prompt
        <<-PROMPT
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

      private

      #
      # Heuristically detects the programming language of a code snippet.
      #
      # It uses a case statement with regular expressions to match common syntax
      # patterns for various languages. If no specific language is matched, it
      # defaults to a generic 'code' identifier.
      #
      # @param code [String] The source code to analyze.
      # @return [String] The lower-case name of the detected language (e.g., 'ruby', 'python')
      #   or 'code' if the language could not be identified.
      #
      def detect_language(code)
        case code
        when /class\s+\w+.*<.*ApplicationRecord/m, /def\s+\w+.*end/m, /require ['"].*['"]/m
          'ruby'
        when /function\s+\w+\s*\(/m, /const\s+\w+\s*=/m, /import\s+.*from/m
          'javascript'
        when /def\s+\w+\s*\(/m, /import\s+\w+/m, /from\s+\w+\s+import/m
          'python'
        when /#include\s*<.*>/m, /int\s+main\s*\(/m
          'c'
        when /public\s+class\s+\w+/m, /import\s+java\./m
          'java'
        when /fn\s+\w+\s*\(/m, /use\s+std::/m
          'rust'
        when /func\s+\w+\s*\(/m, /package\s+main/m
          'go'
        else
          'code'
        end
      end
    end
  end
end
