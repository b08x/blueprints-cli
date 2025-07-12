# frozen_string_literal: true

require 'ruby_llm'
require_relative 'embedding_provider'

module BlueprintsCLI
  module Providers
    # RubyLLM-based embedding provider
    #
    # This provider uses the RubyLLM gem for cloud-based embedding generation.
    # It supports multiple cloud providers (OpenAI, Google, Anthropic, etc.).
    #
    # @example Basic usage
    #   provider = RubyLLMProvider.new
    #   embedding = provider.embed("sample code")
    #
    # @example With custom configuration
    #   provider = RubyLLMProvider.new(
    #     provider: :openai,
    #     model: 'text-embedding-3-small'
    #   )
    #   embedding = provider.embed("sample code")
    #
    class RubyLLMProvider < EmbeddingProvider
      # Default embedding dimensions for common models
      MODEL_DIMENSIONS = {
        'text-embedding-004' => 768, # Google
        'text-embedding-3-small' => 1536,     # OpenAI
        'text-embedding-3-large' => 3072,     # OpenAI
        'text-embedding-ada-002' => 1536      # OpenAI (legacy)
      }.freeze

      # Initialize the RubyLLM provider
      #
      # @param provider [Symbol] Cloud provider (:openai, :google, :anthropic, etc.)
      # @param model [String] Model name for embeddings
      # @param dimensions [Integer] Override embedding dimensions
      # @param options [Hash] Additional options
      def initialize(provider: nil, model: nil, dimensions: nil, **options)
        @provider = provider
        @model = model
        @custom_dimensions = dimensions
        @last_error = nil

        super(**options)

        log("Initialized RubyLLM provider#{" with #{@provider}" if @provider}", level: :info)
      end

      # Generate embedding for given text
      #
      # @param text [String] Text to embed
      # @param options [Hash] Generation options
      # @option options [String] :model Override model for this request
      # @option options [Boolean] :cache Whether to use caching
      # @return [Array<Float>] Embedding vector
      # @raise [EmbeddingError] If embedding generation fails
      def embed(text, **options)
        return [] if text.nil? || text.strip.empty?

        cache_key_str = cache_key(text, **options)

        with_cache(cache_key_str, **options) do
          # Use model override if provided
          embed_options = {}
          embed_options[:model] = options[:model] if options[:model]

          result = RubyLLM.embed(text, **embed_options)

          # Extract the vector array from RubyLLM result
          embedding = result.vectors

          log("Generated embedding via RubyLLM: #{embedding.size} dimensions")
          @last_error = nil

          embedding
        rescue StandardError => e
          @last_error = e
          error_msg = "RubyLLM embedding failed: #{e.message}"
          log(error_msg, level: :error)
          raise EmbeddingError, error_msg
        end
      end

      # Generate embeddings for multiple texts
      #
      # @param texts [Array<String>] Array of texts to embed
      # @param options [Hash] Generation options
      # @return [Array<Array<Float>>] Array of embedding vectors
      def embed_batch(texts, **options)
        return [] if texts.nil? || texts.empty?

        begin
          # RubyLLM doesn't have native batch support, so we process individually
          # This could be optimized in the future if RubyLLM adds batch support
          embeddings = texts.map { |text| embed(text, **options) }

          log("Generated batch embeddings via RubyLLM for #{texts.length} texts")
          embeddings
        rescue StandardError => e
          @last_error = e
          error_msg = "RubyLLM batch embedding failed: #{e.message}"
          log(error_msg, level: :error)
          raise EmbeddingError, error_msg
        end
      end

      # Get embedding dimensions for current model
      #
      # @return [Integer] Number of dimensions
      def dimensions
        return @custom_dimensions if @custom_dimensions

        # Try to determine from model name
        return MODEL_DIMENSIONS[@model] if @model && MODEL_DIMENSIONS[@model]

        # Try to get from RubyLLM configuration
        begin
          # Generate a test embedding to determine dimensions
          test_embedding = embed('test', cache: false)
          test_embedding.length
        rescue StandardError => e
          log("Could not determine dimensions: #{e.message}", level: :warn)
          768 # Default fallback
        end
      end

      # Check if provider is ready
      #
      # @return [Boolean] True if RubyLLM is properly configured
      def healthy?
        # Try a minimal embedding to test configuration
        embed('health check', cache: false)
        @last_error = nil
        true
      rescue StandardError => e
        @last_error = e
        log("Health check failed: #{e.message}", level: :error)
        false
      end

      # Get provider info
      #
      # @return [Hash] Provider information
      def info
        {
          name: 'RubyLLM',
          provider: @provider,
          model: @model,
          dimensions: dimensions,
          last_error: @last_error&.message,
          healthy: healthy?
        }
      end

      # Get last error for debugging
      #
      # @return [Exception, nil] Last error encountered
      attr_reader :last_error

      private

      # Configure the provider (called during initialization)
      def configure
        log('Configuring RubyLLM provider')

        # Check if RubyLLM is properly configured
        begin
          # Verify that at least one API key is available
          config = BlueprintsCLI.configuration
          has_key = %i[openai anthropic gemini deepseek].any? do |provider|
            config.ai_api_key(provider)
          end

          log('Warning: No API keys found for RubyLLM providers', level: :warn) unless has_key
        rescue StandardError => e
          log("Configuration check failed: #{e.message}", level: :warn)
        end
      end
    end

    # Register the RubyLLM provider
    EmbeddingProvider.register(:ruby_llm, RubyLLMProvider)
  end
end
