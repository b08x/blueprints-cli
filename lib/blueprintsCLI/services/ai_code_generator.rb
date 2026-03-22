# frozen_string_literal: true

require_relative "../generators/description"
require_relative "../generators/improvement"
require_relative "../generators/name"

module BlueprintsCLI
  module Services
    #
    # AI-powered code generation service that uses the existing Sublayer
    # infrastructure to generate code based on user prompts and requirements.
    #
    # This service integrates with the existing generator classes and uses
    # the configured LLM providers (Ollama/OpenRouter) to create code snippets
    # based on natural language descriptions.
    #
    class AICodeGenerator
      #
      # Generates code based on a natural language prompt and specifications.
      #
      # @param prompt [String] The natural language description of what to generate
      # @param language [String] The target programming language (default: 'javascript')
      # @param framework [String] The target framework (default: 'react')
      # @param options [Hash] Additional options for code generation
      #
      # @return [Hash] Generated code and metadata
      #
      def generate_code(prompt:, language: "javascript", framework: "react", options: {})
        # Use Sublayer to generate code based on the prompt
        generator = CodeGenerationAgent.new(
          prompt:,
          language:,
          framework:,
          options:
        )

        result = generator.generate

        {
          code: result,
          language:,
          framework:,
          prompt:,
          generated_at: Time.now.iso8601,
          success: true,
        }
      rescue => e
        {
          error: "Code generation failed: #{e.message}",
          success: false,
          generated_at: Time.now.iso8601,
        }
      end

      #
      # Generates metadata for existing code using the Description generator
      #
      # @param code [String] The code to analyze
      # @return [Hash] Generated metadata
      #
      def generate_metadata(code)
        # Use the existing Description generator
        description_generator = BlueprintsCLI::Generators::Description.new(code:)
        description = description_generator.generate

        # Use the existing Name generator if available
        name_generator = BlueprintsCLI::Generators::Name.new(code:)
        name = name_generator.generate

        language = detect_language(code)
        framework = detect_framework(code)

        {
          name:,
          description:,
          language:,
          framework:,
          categories: suggest_categories(code),
          complexity: estimate_complexity(code),
          estimated_lines: code.lines.count,
          generated_at: Time.now.iso8601,
          success: true,
        }
      rescue => e
        {
          error: "Metadata generation failed: #{e.message}",
          success: false,
          generated_at: Time.now.iso8601,
        }
      end

      private def detect_language(code)
        return "javascript" if code.match?(/function\s+\w+\s*\(|const\s+\w+\s*=|import\s+.*from/)
        return "python" if code.match?(/def\s+\w+\s*\(|import\s+\w+|from\s+\w+\s+import/)
        return "ruby" if code.match?(/def\s+\w+.*end|class\s+\w+|require\s+/)
        return "java" if code.match?(/public\s+class\s+\w+|import\s+java\./)
        return "rust" if code.match?(/fn\s+\w+\s*\(|use\s+std::/)
        return "go" if code.match?(/func\s+\w+\s*\(|package\s+main/)

        "unknown"
      end

      private def detect_framework(code)
        return "react" if code.match?(/React|jsx|useState|useEffect/)
        return "vue" if code.match?(/<template>|Vue\.|v-/)
        return "angular" if code.match?(/@Component|Angular|NgModule/)
        return "express" if code.match?(/app\.get|app\.post|express\(\)/)
        return "rails" if code.match?(/ApplicationRecord|Rails\.|render/)

        "none"
      end

      private def suggest_categories(code)
        categories = []
        categories << "component" if code.match?(/Component|export\s+default/)
        categories << "api" if code.match?(/fetch|axios|request|app\.(get|post|put|delete)/)
        categories << "utility" if code.match?(/function/) && !code.match?(/Component/)
        categories << "database" if code.match?(/SELECT|INSERT|UPDATE|DELETE|query|find|save/)
        categories << "test" if code.match?(/describe|it\(|test\(|expect/)
        categories.any? ? categories : ["general"]
      end

      private def estimate_complexity(code)
        lines = code.lines.count

        # Count complexity indicators
        complexity_score = 0
        complexity_score += code.scan(/if\s+|else\s+|elsif\s+|case\s+|when\s+/).length
        complexity_score += code.scan(/for\s+|while\s+|forEach|map\(|filter\(/).length
        complexity_score += code.scan(/function\s+|def\s+|class\s+/).length
        complexity_score += code.scan(/try\s+|catch\s+|rescue\s+/).length

        return "simple" if lines < 20 && complexity_score < 3
        return "medium" if lines < 100 && complexity_score < 10

        "complex"
      end
    end

    # Sublayer generator for code generation
    class CodeGenerationAgent < Sublayer::Generators::Base
      llm_output_adapter type: :single_string,
        name: "generated_code",
        description: "The generated source code based on the user prompt"

      def initialize(prompt:, language:, framework:, options: {})
        @prompt = prompt
        @language = language
        @framework = framework
        @options = options
      end

      def prompt
        base_prompt = <<~PROMPT
          Generate #{@language} code for the following request: #{@prompt}
          
          Requirements:
          - Language: #{@language}
          - Framework: #{@framework}
          - Write clean, well-commented, production-ready code
          - Follow best practices for #{@language} and #{@framework}
          - Include proper error handling where appropriate
          - Make the code reusable and modular
          
        PROMPT

        # Add framework-specific guidance
        case @framework.downcase
        when "react"
          base_prompt += <<~REACT_PROMPT
            
            React-specific requirements:
            - Use functional components with hooks
            - Include proper PropTypes or TypeScript interfaces if applicable
            - Follow React best practices for state management
            - Use modern ES6+ syntax
            - Include proper JSX structure
          REACT_PROMPT
        when "vue"
          base_prompt += <<~VUE_PROMPT
            
            Vue-specific requirements:
            - Use Vue 3 composition API style
            - Include proper template, script, and style sections
            - Follow Vue best practices for reactivity
            - Use proper prop definitions and validation
          VUE_PROMPT
        when "express"
          base_prompt += <<~EXPRESS_PROMPT
            
            Express-specific requirements:
            - Use proper middleware structure
            - Include error handling middleware
            - Follow RESTful API conventions
            - Include proper request/response handling
            - Use async/await for asynchronous operations
          EXPRESS_PROMPT
        end

        base_prompt
      end
    end
  end
end
