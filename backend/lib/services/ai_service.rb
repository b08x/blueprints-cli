# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'

module BlueprintsCLI
  module Services
    ##
    # Service for AI-powered code generation and analysis
    # Provides integration with AI models for code generation and metadata extraction
    #
    class AIService
      include Dry::Monads[:result, :try]
      
      # Default AI service configuration
      DEFAULT_CONFIG = {
        base_url: ENV.fetch('AI_SERVICE_URL', 'http://localhost:8080'),
        timeout: ENV.fetch('AI_SERVICE_TIMEOUT', 30).to_i,
        retries: ENV.fetch('AI_SERVICE_RETRIES', 3).to_i,
        api_key: ENV['AI_SERVICE_API_KEY']
      }.freeze
      
      ##
      # Initialize AI service
      # @param config [Hash] Service configuration
      # @param logger [Logger] Optional logger instance
      def initialize(config: DEFAULT_CONFIG, logger: LOGGER)
        @config = config
        @logger = logger
        @client = build_http_client
      end
      
      ##
      # Generate code from natural language prompt
      # @param prompt [String] Natural language description
      # @param language [String] Target programming language
      # @param framework [String] Target framework
      # @param options [Hash] Generation options
      # @option options [String] :style Code style preference ('functional', 'class', 'mixed')
      # @option options [Boolean] :typescript Generate TypeScript code
      # @option options [Boolean] :testing Include test cases
      # @return [Hash] Generation result
      def generate_code(prompt:, language: 'javascript', framework: nil, options: {})
        Try do
          @logger.info "Generating code for prompt: #{prompt[0..50]}..."
          
          request_payload = {
            prompt: prompt,
            language: language,
            framework: framework,
            options: options,
            timestamp: Time.now.iso8601
          }
          
          response = @client.post('/v1/generate', request_payload.to_json)
          
          if response.success?
            result = JSON.parse(response.body, symbolize_names: true)
            
            # Add metadata
            result.merge!(
              generated_at: Time.now.iso8601,
              estimated_lines: count_lines(result[:code]),
              complexity: assess_complexity(result[:code])
            )
            
            @logger.info "Code generation successful"
            result
          else
            raise_api_error(response)
          end
        end.to_result.or do |error|
          @logger.error "Code generation failed: #{error.message}"
          {
            success: false,
            error: error.message,
            timestamp: Time.now.iso8601
          }
        end
      end
      
      ##
      # Analyze code and generate metadata
      # @param code [String] Code content to analyze
      # @param options [Hash] Analysis options
      # @return [Hash] Analysis result with metadata
      def analyze_code(code, options: {})
        Try do
          @logger.info "Analyzing code (#{code.length} characters)"
          
          request_payload = {
            code: code,
            options: options,
            timestamp: Time.now.iso8601
          }
          
          response = @client.post('/v1/analyze', request_payload.to_json)
          
          if response.success?
            result = JSON.parse(response.body, symbolize_names: true)
            
            # Enrich with local analysis
            result.merge!(
              analyzed_at: Time.now.iso8601,
              estimated_lines: count_lines(code),
              complexity: assess_complexity(code),
              detected_patterns: detect_patterns(code)
            )
            
            @logger.info "Code analysis successful"
            result
          else
            raise_api_error(response)
          end
        end.to_result.or do |error|
          @logger.error "Code analysis failed: #{error.message}"
          
          # Fallback to local analysis
          fallback_analysis(code, error)
        end
      end
      
      ##
      # Generate blueprint metadata from code
      # @param code [String] Code content
      # @return [Hash] Generated metadata
      def generate_metadata(code)
        Try do
          @logger.info "Generating metadata for code"
          
          # First try AI analysis
          ai_result = analyze_code(code)
          
          if ai_result[:success] != false
            {
              success: true,
              metadata: extract_metadata_from_analysis(ai_result)
            }
          else
            # Fallback to rule-based metadata generation
            {
              success: true,
              metadata: generate_fallback_metadata(code)
            }
          end
        end.to_result.or do |error|
          @logger.error "Metadata generation failed: #{error.message}"
          {
            success: false,
            error: error.message
          }
        end
      end
      
      ##
      # Check if AI service is available
      # @return [Boolean] Service availability status
      def available?
        Try do
          response = @client.get('/health', nil, { timeout: 5 })
          response.success?
        end.to_result.or do |error|
          @logger.warn "AI service health check failed: #{error.message}"
          false
        end
      end
      
      private
      
      ##
      # Build HTTP client with retry configuration
      # @return [Faraday::Connection] Configured HTTP client
      def build_http_client
        Faraday.new(url: @config[:base_url]) do |conn|
          conn.request :json
          conn.request :retry, {
            max: @config[:retries],
            interval: 0.5,
            backoff_factor: 2,
            retry_statuses: [429, 500, 502, 503, 504]
          }
          
          conn.response :raise_error
          conn.adapter Faraday.default_adapter
          
          # Set timeout
          conn.options.timeout = @config[:timeout]
          conn.options.open_timeout = 10
          
          # Add API key if configured
          if @config[:api_key]
            conn.headers['Authorization'] = "Bearer #{@config[:api_key]}"
          end
          
          conn.headers['Content-Type'] = 'application/json'
          conn.headers['User-Agent'] = 'BlueprintsCLI-API/1.0.0'
        end
      end
      
      ##
      # Raise appropriate error from API response
      # @param response [Faraday::Response] HTTP response
      def raise_api_error(response)
        error_data = JSON.parse(response.body) rescue { 'error' => 'Unknown API error' }
        raise StandardError, "AI service error (#{response.status}): #{error_data['error'] || error_data['message']}"
      end
      
      ##
      # Count lines in code
      # @param code [String] Code content
      # @return [Integer] Line count
      def count_lines(code)
        return 0 unless code
        code.lines.count
      end
      
      ##
      # Assess code complexity (basic heuristic)
      # @param code [String] Code content
      # @return [String] Complexity level ('low', 'medium', 'high')
      def assess_complexity(code)
        return 'low' unless code
        
        lines = count_lines(code)
        
        # Simple heuristic based on line count and complexity indicators
        complexity_indicators = [
          /class\s+\w+/i,      # Class definitions
          /function\s+\w+/i,   # Function definitions
          /if\s*\(/i,          # Conditionals
          /for\s*\(/i,         # Loops
          /while\s*\(/i,       # While loops
          /switch\s*\(/i,      # Switch statements
          /try\s*\{/i          # Try-catch blocks
        ]
        
        indicator_count = complexity_indicators.sum { |pattern| code.scan(pattern).length }
        
        case [lines, indicator_count]
        in [0..20, 0..3]
          'low'
        in [21..100, 0..10] | [0..20, 4..10]
          'medium'
        else
          'high'
        end
      end
      
      ##
      # Detect common patterns in code
      # @param code [String] Code content
      # @return [Array<String>] Detected patterns
      def detect_patterns(code)
        return [] unless code
        
        patterns = []
        patterns << 'component' if code.match?(/export\s+default\s+\w+|React\./i)
        patterns << 'hook' if code.match?(/use\w+|useState|useEffect/i)
        patterns << 'api' if code.match?(/app\.(get|post|put|delete)/i)
        patterns << 'async' if code.match?/(async|await)/i)
        patterns << 'class' if code.match?(/class\s+\w+/i)
        patterns << 'functional' if code.match?(/const\s+\w+\s*=\s*\(/i)
        
        patterns
      end
      
      ##
      # Extract metadata from AI analysis result
      # @param analysis_result [Hash] AI analysis result
      # @return [Hash] Extracted metadata
      def extract_metadata_from_analysis(analysis_result)
        {
          name: analysis_result[:name] || 'Generated Code',
          description: analysis_result[:description] || 'AI-generated code snippet',
          language: analysis_result[:language] || 'javascript',
          framework: analysis_result[:framework],
          categories: analysis_result[:categories] || [],
          complexity: analysis_result[:complexity] || 'medium',
          estimated_lines: analysis_result[:estimated_lines] || 0,
          patterns: analysis_result[:detected_patterns] || [],
          generated_at: Time.now.iso8601
        }
      end
      
      ##
      # Generate fallback metadata using local analysis
      # @param code [String] Code content
      # @return [Hash] Fallback metadata
      def generate_fallback_metadata(code)
        {
          name: 'Code Snippet',
          description: 'Code snippet analyzed locally',
          language: detect_language(code),
          framework: detect_framework(code),
          categories: detect_patterns(code),
          complexity: assess_complexity(code),
          estimated_lines: count_lines(code),
          patterns: detect_patterns(code),
          generated_at: Time.now.iso8601
        }
      end
      
      ##
      # Fallback analysis when AI service fails
      # @param code [String] Code content
      # @param error [Exception] Original error
      # @return [Hash] Fallback analysis result
      def fallback_analysis(code, error)
        @logger.warn "Using fallback analysis due to AI service failure"
        
        {
          success: true,
          fallback: true,
          name: 'Code Snippet',
          description: 'Analyzed using fallback methods',
          language: detect_language(code),
          framework: detect_framework(code),
          categories: detect_patterns(code),
          complexity: assess_complexity(code),
          estimated_lines: count_lines(code),
          analyzed_at: Time.now.iso8601,
          ai_error: error.message
        }
      end
      
      ##
      # Detect programming language from code
      # @param code [String] Code content
      # @return [String] Detected language
      def detect_language(code)
        return 'javascript' unless code
        
        # Simple language detection based on syntax patterns
        case code
        when /import.*from|export.*|const.*=>/
          'javascript'
        when /def\s+\w+|class.*:/
          'python'
        when /def\s+\w+|class\s+\w+|require/
          'ruby'
        when /public\s+class|import\s+java/
          'java'
        when /using\s+System|namespace/
          'csharp'
        when /func\s+\w+|package\s+main/
          'go'
        when /fn\s+\w+|use\s+std/
          'rust'
        else
          'javascript'  # Default
        end
      end
      
      ##
      # Detect framework from code
      # @param code [String] Code content
      # @return [String, nil] Detected framework
      def detect_framework(code)
        return nil unless code
        
        case code
        when /React|jsx|useState/
          'react'
        when /Vue|@vue/
          'vue'
        when /@angular|Angular/
          'angular'
        when /svelte/
          'svelte'
        when /express|app\.(get|post)/
          'express'
        when /django|from django/
          'django'
        when /rails|ActiveRecord/
          'rails'
        when /spring|@SpringBootApplication/
          'spring'
        else
          nil
        end
      end
    end
  end
end