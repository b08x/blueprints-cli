# frozen_string_literal: true

module BlueprintsCLI
  module Providers
    # Abstract base class for embedding providers
    #
    # This class defines the interface that all embedding providers must implement.
    # It supports different providers (Informers, RubyLLM, etc.) with a unified API.
    #
    # @example Basic usage
    #   provider = EmbeddingProvider.create(:informers)
    #   embedding = provider.embed("sample text")
    #
    # @example With options
    #   embedding = provider.embed("code snippet", normalize: true, model: "custom-model")
    #
    class EmbeddingProvider
      # Registry of available providers
      @providers = {}

      # Error raised when a provider is not found
      ProviderNotFoundError = Class.new(StandardError)

      # Error raised when embedding generation fails
      EmbeddingError = Class.new(StandardError)

      class << self
        # Register a provider class
        #
        # @param name [Symbol] Provider name
        # @param provider_class [Class] Provider class
        def register(name, provider_class)
          @providers[name.to_sym] = provider_class
        end

        # Create a provider instance
        #
        # @param name [Symbol] Provider name
        # @param options [Hash] Provider-specific options
        # @return [EmbeddingProvider] Provider instance
        # @raise [ProviderNotFoundError] If provider is not registered
        def create(name, **options)
          provider_class = @providers[name.to_sym]
          raise ProviderNotFoundError, "Unknown provider: #{name}" unless provider_class

          provider_class.new(**options)
        end

        # List available providers
        #
        # @return [Array<Symbol>] Available provider names
        def available_providers
          @providers.keys
        end

        # Check if provider is available
        #
        # @param name [Symbol] Provider name
        # @return [Boolean] True if provider is registered
        def provider_available?(name)
          @providers.key?(name.to_sym)
        end
      end

      # Initialize the provider
      #
      # @param options [Hash] Provider-specific configuration options
      def initialize(**options)
        @options = options
        @cache = {}
        @stats = { embeddings_generated: 0, cache_hits: 0 }

        configure if respond_to?(:configure, true)
      end

      # Generate embeddings for given text
      #
      # This is the main interface method that must be implemented by subclasses.
      #
      # @param text [String] Text to embed
      # @param options [Hash] Generation options
      # @option options [Boolean] :normalize Whether to normalize the embedding vector
      # @option options [String] :model Model name to use for embedding
      # @option options [Boolean] :cache Whether to use caching (default: true)
      # @return [Array<Float>] Embedding vector
      # @raise [NotImplementedError] If not implemented by subclass
      def embed(text, **options)
        raise NotImplementedError, "#{self.class.name} must implement #embed"
      end

      # Generate embeddings for multiple texts (batch processing)
      #
      # Default implementation calls embed for each text individually.
      # Subclasses can override for more efficient batch processing.
      #
      # @param texts [Array<String>] Array of texts to embed
      # @param options [Hash] Generation options
      # @return [Array<Array<Float>>] Array of embedding vectors
      def embed_batch(texts, **options)
        texts.map { |text| embed(text, **options) }
      end

      # Get embedding dimensions for this provider
      #
      # @return [Integer] Number of dimensions in embedding vectors
      # @raise [NotImplementedError] If not implemented by subclass
      def dimensions
        raise NotImplementedError, "#{self.class.name} must implement #dimensions"
      end

      # Check if provider is ready/healthy
      #
      # @return [Boolean] True if provider is operational
      def healthy?
        true
      end

      # Get provider statistics
      #
      # @return [Hash] Statistics about provider usage
      def stats
        @stats.dup
      end

      # Clear embedding cache
      #
      # @return [Integer] Number of cache entries cleared
      def clear_cache
        cleared = @cache.size
        @cache.clear
        cleared
      end

      # Get cache statistics
      #
      # @return [Hash] Cache usage statistics
      def cache_stats
        {
          size: @cache.size,
          hit_rate: @stats[:cache_hits].to_f / [@stats[:embeddings_generated], 1].max
        }
      end

      protected

      # Get cached embedding or generate new one
      #
      # @param cache_key [String] Cache key
      # @param options [Hash] Generation options
      # @yield Block that generates the embedding
      # @return [Array<Float>] Embedding vector
      def with_cache(cache_key, **options)
        use_cache = options.fetch(:cache, true)

        if use_cache && @cache.key?(cache_key)
          @stats[:cache_hits] += 1
          BlueprintsCLI.logger.debug("Cache hit for embedding: #{cache_key[0..50]}...")
          return @cache[cache_key]
        end

        embedding = yield

        @cache[cache_key] = embedding if use_cache
        @stats[:embeddings_generated] += 1

        embedding
      end

      # Generate cache key for text and options
      #
      # @param text [String] Input text
      # @param options [Hash] Generation options
      # @return [String] Cache key
      def cache_key(text, **options)
        # Include relevant options in cache key
        key_options = options.slice(:model, :normalize)
        "#{text.hash}_#{key_options.hash}"
      end

      # Log provider activity
      #
      # @param message [String] Log message
      # @param level [Symbol] Log level
      def log(message, level: :debug)
        BlueprintsCLI.logger.send(level, "[#{self.class.name}] #{message}")
      end
    end
  end
end
