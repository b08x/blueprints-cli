# frozen_string_literal: true

require 'informers'
require_relative 'embedding_provider'

module BlueprintsCLI
  module Providers
    # Informers-based embedding provider
    #
    # This provider uses the Informers gem for local embedding generation.
    # It supports sentence transformers and feature extraction models.
    #
    # @example Basic usage
    #   provider = InformersProvider.new
    #   embedding = provider.embed("sample code")
    #
    # @example With custom model
    #   provider = InformersProvider.new(model: "sentence-transformers/all-MiniLM-L6-v2")
    #   embedding = provider.embed("sample code")
    #
    class InformersProvider < EmbeddingProvider
      # Default model for embeddings
      DEFAULT_MODEL = 'sentence-transformers/all-MiniLM-L6-v2'

      # Default embedding dimensions for common models
      MODEL_DIMENSIONS = {
        'sentence-transformers/all-MiniLM-L6-v2' => 384,
        'sentence-transformers/all-MiniLM-L12-v2' => 384,
        'sentence-transformers/all-mpnet-base-v2' => 768,
        'sentence-transformers/multi-qa-MiniLM-L6-cos-v1' => 384,
        'thenlper/gte-small' => 384,
        'thenlper/gte-base' => 768
      }.freeze

      # Initialize the Informers provider
      #
      # @param model [String] Model name to use for embeddings
      # @param device [String] Device to run on ('cpu', 'cuda', etc.)
      # @param quantized [Boolean] Whether to use quantized models
      # @param max_length [Integer] Maximum input length
      # @param options [Hash] Additional options
      def initialize(model: DEFAULT_MODEL, device: 'cpu', quantized: true, max_length: 512,
                     **options)
        @model_name = model
        @device = device
        @quantized = quantized
        @max_length = max_length
        @pipeline = nil
        @model_dimensions = nil

        super(**options)

        log("Initialized Informers provider with model: #{@model_name}", level: :info)
      end

      # Generate embedding for given text
      #
      # @param text [String] Text to embed
      # @param options [Hash] Generation options
      # @option options [Boolean] :normalize Whether to normalize the embedding
      # @option options [String] :model Override model for this request
      # @option options [Boolean] :cache Whether to use caching
      # @return [Array<Float>] Embedding vector
      # @raise [EmbeddingError] If embedding generation fails
      def embed(text, **options)
        return [] if text.nil? || text.strip.empty?

        # Truncate text if too long
        processed_text = truncate_text(text, @max_length)
        cache_key_str = cache_key(processed_text, **options)

        with_cache(cache_key_str, **options) do
          ensure_pipeline_loaded

          # Generate embedding using Informers pipeline
          result = @pipeline.call(processed_text)
          embedding = extract_embedding(result)

          # Normalize if requested
          embedding = normalize_vector(embedding) if options[:normalize]

          log("Generated embedding for text (#{processed_text.length} chars): #{embedding.size} dimensions")
          embedding
        rescue StandardError => e
          error_msg = "Failed to generate embedding: #{e.message}"
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
          ensure_pipeline_loaded

          # Process all texts in batch for efficiency
          processed_texts = texts.map { |text| truncate_text(text, @max_length) }

          # For single text, wrap in array; for multiple, pass as-is
          input = processed_texts.length == 1 ? processed_texts.first : processed_texts

          result = @pipeline.call(input)
          embeddings = extract_batch_embeddings(result, processed_texts.length)

          # Normalize if requested
          embeddings = embeddings.map { |emb| normalize_vector(emb) } if options[:normalize]

          @stats[:embeddings_generated] += processed_texts.length
          log("Generated batch embeddings for #{processed_texts.length} texts")

          embeddings
        rescue StandardError => e
          error_msg = "Failed to generate batch embeddings: #{e.message}"
          log(error_msg, level: :error)
          raise EmbeddingError, error_msg
        end
      end

      # Get embedding dimensions for current model
      #
      # @return [Integer] Number of dimensions
      def dimensions
        @model_dimensions ||= begin
          # Try to get from known models first
          known_dims = MODEL_DIMENSIONS[@model_name]
          return known_dims if known_dims

          # If unknown model, generate a test embedding to determine dimensions
          begin
            ensure_pipeline_loaded
            test_embedding = embed('test', cache: false)
            test_embedding.length
          rescue StandardError => e
            log("Could not determine dimensions for model #{@model_name}: #{e.message}",
                level: :warn)
            384 # Default fallback
          end
        end
      end

      # Check if provider is ready
      #
      # @return [Boolean] True if Informers pipeline is loaded successfully
      def healthy?
        ensure_pipeline_loaded
        true
      rescue StandardError => e
        log("Health check failed: #{e.message}", level: :error)
        false
      end

      # Get provider info
      #
      # @return [Hash] Provider information
      def info
        {
          name: 'Informers',
          model: @model_name,
          device: @device,
          quantized: @quantized,
          dimensions: dimensions,
          max_length: @max_length,
          pipeline_loaded: !@pipeline.nil?
        }
      end

      private

      # Ensure the Informers pipeline is loaded
      def ensure_pipeline_loaded
        return if @pipeline

        log("Loading Informers pipeline: #{@model_name}")

        begin
          @pipeline = Informers.pipeline(
            'embedding',
            @model_name,
            quantized: @quantized,
            device: @device
          )

          log('Successfully loaded Informers pipeline', level: :info)
        rescue StandardError => e
          error_msg = "Failed to load Informers pipeline: #{e.message}"
          log(error_msg, level: :error)
          raise EmbeddingError, error_msg
        end
      end

      # Extract embedding from pipeline result
      #
      # @param result [Object] Pipeline result
      # @return [Array<Float>] Embedding vector
      def extract_embedding(result)
        case result
        when Array
          # If array of arrays, take the first one
          result.first.is_a?(Array) ? result.first : result
        when Hash
          # Look for common embedding keys
          result[:embedding] || result['embedding'] ||
            result[:sentence_embedding] || result['sentence_embedding'] ||
            result[:pooler_output] || result['pooler_output'] ||
            (raise EmbeddingError, "Could not extract embedding from result: #{result.keys}")
        else
          # Assume it's the embedding directly
          result.to_a
        end
      end

      # Extract embeddings from batch result
      #
      # @param result [Object] Pipeline batch result
      # @param expected_count [Integer] Expected number of embeddings
      # @return [Array<Array<Float>>] Array of embedding vectors
      def extract_batch_embeddings(result, _expected_count)
        case result
        when Array
          # Check if it's a nested array (batch of embeddings)
          if result.first.is_a?(Array)
            result
          else
            # Single embedding, wrap in array
            [result]
          end
        else
          # Single result, extract and wrap
          [extract_embedding(result)]
        end
      end

      # Truncate text to maximum length
      #
      # @param text [String] Input text
      # @param max_length [Integer] Maximum length
      # @return [String] Truncated text
      def truncate_text(text, max_length)
        return text if text.length <= max_length

        # Try to truncate at word boundaries
        words = text.split
        truncated = ''

        words.each do |word|
          break unless (truncated + ' ' + word).length <= max_length

          truncated += (truncated.empty? ? '' : ' ') + word
        end

        # If we couldn't fit any words, just slice the text
        truncated = text[0, max_length] if truncated.empty?

        if text.length != truncated.length
          log("Truncated text from #{text.length} to #{truncated.length} characters")
        end
        truncated
      end

      # Normalize embedding vector to unit length
      #
      # @param vector [Array<Float>] Input vector
      # @return [Array<Float>] Normalized vector
      def normalize_vector(vector)
        magnitude = Math.sqrt(vector.sum { |x| x * x })
        return vector if magnitude.zero?

        vector.map { |x| x / magnitude }
      end

      # Configure the provider (called during initialization)
      def configure
        log('Configuring Informers provider')

        # Set device if CUDA is requested but not available
        return unless @device == 'cuda'

        log('CUDA device requested - ensure ONNX CUDA providers are available', level: :warn)
      end
    end

    # Register the Informers provider
    EmbeddingProvider.register(:informers, InformersProvider)
  end
end
