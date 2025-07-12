# frozen_string_literal: true

require 'ruby_llm'
require 'json'
require_relative '../configuration'
require_relative '../logger'

module BlueprintsCLI
  module Generators
    # Response object for improvement suggestions that provides both Array interface
    # for backward compatibility and metadata access for enhanced functionality.
    #
    # This object is returned by {Improvement#generate} and acts as a hybrid between
    # a simple Array<String> (for backward compatibility) and a rich response object
    # with metadata (for enhanced functionality).
    #
    # @example Array-like interface (backward compatibility)
    #   response.each { |improvement| puts improvement }
    #   first_improvement = response[0]
    #   puts "Found #{response.length} improvements"
    #
    # @example Metadata interface (enhanced functionality)
    #   puts "Model: #{response.model_info[:model_id]}"
    #   puts "Tokens: #{response.token_usage[:total_tokens]}"
    #   puts "Success: #{response.success?}"
    class ImprovementResponse
      include Enumerable

      # @return [Array<String>] The list of improvement suggestions
      attr_reader :improvements

      # @return [Hash] Metadata about the response (tokens, model, timing, errors)
      attr_reader :metadata

      # @return [RubyLLM::Message, nil] The raw response from RubyLLM
      attr_reader :raw_response

      # Creates a new ImprovementResponse instance.
      #
      # @param improvements [Array<String>] List of improvement suggestions
      # @param metadata [Hash] Response metadata (tokens, model, timing, etc.)
      # @param raw_response [RubyLLM::Message, nil] Raw LLM response object
      def initialize(improvements:, metadata:, raw_response:)
        @improvements = Array(improvements)
        @metadata = metadata || {}
        @raw_response = raw_response
      end

      # Array-like interface for backward compatibility
      def each(&block)
        @improvements.each(&block)
      end

      def [](index)
        @improvements[index]
      end

      def length
        @improvements.length
      end
      alias size length

      def empty?
        @improvements.empty?
      end

      def to_a
        @improvements.dup
      end

      def first
        @improvements.first
      end

      def last
        @improvements.last
      end

      def any?
        !@improvements.empty?
      end

      # Returns token usage information.
      #
      # @return [Hash] Token usage with keys:
      #   - :input_tokens [Integer] Tokens in the request
      #   - :output_tokens [Integer] Tokens in the response
      #   - :total_tokens [Integer] Sum of input and output tokens
      def token_usage
        {
          input_tokens: @metadata[:input_tokens] || 0,
          output_tokens: @metadata[:output_tokens] || 0,
          total_tokens: (@metadata[:input_tokens] || 0) + (@metadata[:output_tokens] || 0)
        }
      end

      # Returns model information.
      #
      # @return [Hash] Model info with keys:
      #   - :model_id [String] The model identifier used
      #   - :provider [String] The AI provider name
      def model_info
        {
          model_id: @metadata[:model_id],
          provider: @metadata[:provider]
        }
      end

      # Returns the response time in seconds.
      #
      # @return [Float, nil] Time taken to generate the response
      def response_time
        @metadata[:response_time]
      end

      # Checks if the generation was successful.
      #
      # @return [Boolean] true if improvements were generated, false if error occurred
      def success?
        !@improvements.empty? && !@metadata[:error]
      end

      # JSON serialization including both improvements and metadata.
      #
      # @return [String] JSON representation
      def to_json(*args)
        {
          improvements: @improvements,
          metadata: @metadata,
          success: success?
        }.to_json(*args)
      end

      def inspect
        "#<ImprovementResponse improvements=#{@improvements.length} items, tokens=#{token_usage[:total_tokens]}>"
      end
    end

    # Analyzes a given code blueprint using RubyLLM to suggest specific, actionable
    # improvements across various categories like quality, performance, and security.
    #
    # This generator replaces the previous Sublayer-based implementation with RubyLLM,
    # providing the same interface while adding metadata access capabilities and
    # improved reliability.
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
    #
    #   result = generator.generate
    #
    #   # Backward compatible usage
    #   result.each { |suggestion| puts suggestion }
    #
    #   # New metadata access
    #   puts "Used #{result.token_usage[:total_tokens]} tokens"
    #   puts "Model: #{result.model_info[:model_id]}"
    class Improvement
      # Error raised when LLM response cannot be parsed
      ParseError = Class.new(StandardError)

      # Error raised when LLM communication fails
      CommunicationError = Class.new(StandardError)

      # Initializes a new Improvement instance.
      #
      # @param code [String] The source code to be analyzed.
      # @param description [String, nil] An optional high-level description of the code's
      #   functionality to provide more context to the LLM.
      def initialize(code:, description: nil)
        @code = code
        @description = description
        @config = BlueprintsCLI::Configuration.new
      end

      # Executes the code analysis and returns the suggested improvements.
      #
      # This method creates a RubyLLM chat instance, sends the analysis prompt,
      # and parses the response into a structured ImprovementResponse object.
      #
      # @return [ImprovementResponse] A response object that acts like Array<String>
      #   for backward compatibility but also provides metadata access.
      def generate
        start_time = Time.now

        begin
          # Create RubyLLM chat instance with configured model
          chat = create_chat_instance

          # Send the analysis prompt
          response = chat.ask(build_prompt)

          end_time = Time.now
          response_time = end_time - start_time

          # Parse improvements from response
          improvements = parse_improvements(response.content)

          # Build metadata
          metadata = build_metadata(response, response_time)

          # Return hybrid response object
          ImprovementResponse.new(
            improvements: improvements,
            metadata: metadata,
            raw_response: response
          )
        rescue StandardError => e
          handle_error(e, start_time)
        end
      end

      private

      # Creates a RubyLLM chat instance with appropriate configuration
      #
      # @return [RubyLLM::Chat] Configured chat instance
      def create_chat_instance
        # Get model from configuration, fallback to default
        model = @config.fetch(:ai, :rubyllm, :default_model) || 'gemini-2.0-flash'

        # Create chat with system instructions for structured output
        chat = RubyLLM.chat(model: model)
        chat.with_instructions(system_instructions)

        chat
      end

      # System instructions for the LLM to ensure structured output
      #
      # @return [String] System instructions
      def system_instructions
        <<~INSTRUCTIONS
          You are a senior software engineer and code reviewer. Your task is to analyze code and provide specific, actionable improvement suggestions.

          Always respond with valid JSON in the exact format requested. Each improvement should be:
          - Specific and actionable
          - Focused on a single improvement area
          - Written as a complete sentence
          - Practical and implementable

          Do not include explanations outside the JSON response.
        INSTRUCTIONS
      end

      # Builds the analysis prompt for the LLM
      #
      # @return [String] The complete prompt to be sent for analysis
      def build_prompt
        <<~PROMPT
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

          Please respond with a JSON object in this exact format:
          {
            "improvements": [
              "First improvement suggestion here",
              "Second improvement suggestion here",
              "Third improvement suggestion here"
            ]
          }
        PROMPT
      end

      # Parses improvement suggestions from LLM response content
      #
      # @param content [String] The raw response content from the LLM
      # @return [Array<String>] Array of improvement suggestions
      # @raise [ParseError] If the response cannot be parsed
      def parse_improvements(content)
        # Try to extract JSON from the response
        json_match = content.match(/\{.*\}/m)
        raise ParseError, 'No JSON found in response' unless json_match

        json_content = json_match[0]
        parsed = JSON.parse(json_content)

        improvements = parsed['improvements']
        raise ParseError, "No 'improvements' key found in response" unless improvements
        raise ParseError, 'Improvements is not an array' unless improvements.is_a?(Array)
        raise ParseError, 'No improvements found' if improvements.empty?

        # Clean up and validate improvements
        improvements.map(&:strip).reject(&:empty?)
      rescue JSON::ParserError => e
        raise ParseError, "Invalid JSON in response: #{e.message}"
      end

      # Builds metadata hash from response and timing information
      #
      # @param response [RubyLLM::Message] The LLM response object
      # @param response_time [Float] Time taken for the request
      # @return [Hash] Metadata hash
      def build_metadata(response, response_time)
        {
          model_id: response.model_id,
          provider: extract_provider_from_model(response.model_id),
          input_tokens: response.input_tokens,
          output_tokens: response.output_tokens,
          total_tokens: (response.input_tokens || 0) + (response.output_tokens || 0),
          response_time: response_time,
          timestamp: Time.now.iso8601
        }
      end

      # Extracts provider name from model ID
      #
      # @param model_id [String] The model identifier
      # @return [String] Provider name
      def extract_provider_from_model(model_id)
        case model_id
        when /gemini/i
          'Google'
        when /gpt|openai/i
          'OpenAI'
        when /claude/i
          'Anthropic'
        when /deepseek/i
          'DeepSeek'
        else
          'Unknown'
        end
      end

      # Handles errors during generation process
      #
      # @param error [StandardError] The error that occurred
      # @param start_time [Time] When the generation started
      # @return [ImprovementResponse] Error response object
      def handle_error(error, start_time)
        end_time = Time.now
        response_time = end_time - start_time

        # Log the error
        BlueprintsCLI.logger.warn("Improvement generation failed: #{error.message}")
        BlueprintsCLI.logger.debug(error.backtrace.join("\n")) if ENV['DEBUG']

        # Return empty response with error metadata
        ImprovementResponse.new(
          improvements: [],
          metadata: {
            error: error.message,
            error_type: error.class.name,
            response_time: response_time,
            timestamp: Time.now.iso8601
          },
          raw_response: nil
        )
      end
    end
  end
end
