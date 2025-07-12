# frozen_string_literal: true

require 'singleton'
require_relative '../providers/embedding_provider'
require_relative '../providers/informers_provider'
require_relative '../providers/ruby_llm_provider'

module BlueprintsCLI
  module Services
    # Singleton service for managing embedding generation
    #
    # This service provides a thread-safe, memory-efficient way to generate embeddings
    # using different providers (Informers, RubyLLM). It includes provider fallback,
    # caching, and performance monitoring.
    #
    # @example Basic usage
    #   service = InformersEmbeddingService.instance
    #   embedding = service.embed("sample code")
    #
    # @example With provider selection
    #   service = InformersEmbeddingService.instance
    #   embedding = service.embed("sample code", provider: :informers)
    #
    # @example Batch processing
    #   texts = ["code1", "code2", "code3"]
    #   embeddings = service.embed_batch(texts)
    #
    class InformersEmbeddingService
      include Singleton

      # Default provider priority order
      DEFAULT_PROVIDERS = %i[informers ruby_llm].freeze

      # Service configuration
      attr_reader :config, :stats

      # Initialize the singleton instance
      def initialize
        @providers = {}
        @config = load_configuration
        @stats = {
          total_requests: 0,
          successful_requests: 0,
          failed_requests: 0,
          provider_usage: {},
          cache_hits: 0,
          average_response_time: 0.0
        }
        @mutex = Mutex.new

        BlueprintsCLI.logger.info('InformersEmbeddingService initialized')
      end

      # Generate embedding for given text
      #
      # @param text [String] Text to embed
      # @param provider [Symbol, nil] Specific provider to use
      # @param options [Hash] Generation options
      # @option options [Boolean] :normalize Whether to normalize the embedding
      # @option options [Boolean] :cache Whether to use caching (default: true)
      # @option options [Array<Symbol>] :fallback_providers Alternative providers to try
      # @return [Array<Float>] Embedding vector
      # @raise [Providers::EmbeddingProvider::EmbeddingError] If all providers fail
      def embed(text, provider: nil, **options)
        start_time = Time.now

        @mutex.synchronize do
          @stats[:total_requests] += 1
        end

        begin
          result = generate_embedding(text, provider, **options)

          @mutex.synchronize do
            @stats[:successful_requests] += 1
            update_response_time(Time.now - start_time)
          end

          result
        rescue StandardError => e
          @mutex.synchronize do
            @stats[:failed_requests] += 1
          end

          BlueprintsCLI.logger.error("Embedding generation failed: #{e.message}")
          raise
        end
      end

      # Generate embeddings for multiple texts
      #
      # @param texts [Array<String>] Array of texts to embed
      # @param provider [Symbol, nil] Specific provider to use
      # @param options [Hash] Generation options
      # @return [Array<Array<Float>>] Array of embedding vectors
      def embed_batch(texts, provider: nil, **options)
        return [] if texts.nil? || texts.empty?

        start_time = Time.now

        @mutex.synchronize do
          @stats[:total_requests] += texts.length
        end

        begin
          # Try to use batch processing if available
          selected_provider = get_provider(provider || @config[:default_provider])

          result = if selected_provider.respond_to?(:embed_batch)
                     selected_provider.embed_batch(texts, **options)
                   else
                     # Fallback to individual processing
                     texts.map { |text| selected_provider.embed(text, **options) }
                   end

          @mutex.synchronize do
            @stats[:successful_requests] += texts.length
            @stats[:provider_usage][selected_provider.class.name] ||= 0
            @stats[:provider_usage][selected_provider.class.name] += texts.length
            update_response_time(Time.now - start_time)
          end

          result
        rescue StandardError => e
          @mutex.synchronize do
            @stats[:failed_requests] += texts.length
          end

          BlueprintsCLI.logger.error("Batch embedding generation failed: #{e.message}")
          raise
        end
      end

      # Get embedding dimensions for a provider
      #
      # @param provider [Symbol, nil] Provider name
      # @return [Integer] Number of dimensions
      def dimensions(provider: nil)
        selected_provider = get_provider(provider || @config[:default_provider])
        selected_provider.dimensions
      end

      # Check service health
      #
      # @return [Hash] Health status of all providers
      def health_check
        results = {}

        available_providers.each do |provider_name|
          provider = get_provider(provider_name)
          results[provider_name] = {
            healthy: provider.healthy?,
            info: provider.respond_to?(:info) ? provider.info : {},
            stats: provider.respond_to?(:stats) ? provider.stats : {}
          }
        rescue StandardError => e
          results[provider_name] = {
            healthy: false,
            error: e.message
          }
        end

        results
      end

      # Get available providers
      #
      # @return [Array<Symbol>] List of available provider names
      def available_providers
        Providers::EmbeddingProvider.available_providers
      end

      # Reset service statistics
      def reset_stats
        @mutex.synchronize do
          @stats = {
            total_requests: 0,
            successful_requests: 0,
            failed_requests: 0,
            provider_usage: {},
            cache_hits: 0,
            average_response_time: 0.0
          }
        end

        # Reset provider caches
        @providers.each_value do |provider|
          provider.clear_cache if provider.respond_to?(:clear_cache)
        end
      end

      # Get service statistics
      #
      # @return [Hash] Service usage statistics
      def service_stats
        @mutex.synchronize do
          @stats.merge(
            success_rate: success_rate,
            provider_count: @providers.size,
            cache_stats: aggregate_cache_stats
          )
        end
      end

      # Clear all provider caches
      #
      # @return [Hash] Cache clearing results per provider
      def clear_caches
        results = {}

        @providers.each do |name, provider|
          results[name] = provider.clear_cache if provider.respond_to?(:clear_cache)
        end

        results
      end

      private

      # Generate embedding with provider fallback
      def generate_embedding(text, provider_name, **options)
        providers_to_try = determine_providers(provider_name, options[:fallback_providers])
        last_error = nil

        providers_to_try.each do |prov_name|
          provider = get_provider(prov_name)
          result = provider.embed(text, **options)

          @mutex.synchronize do
            @stats[:provider_usage][provider.class.name] ||= 0
            @stats[:provider_usage][provider.class.name] += 1
          end

          return result
        rescue StandardError => e
          last_error = e
          BlueprintsCLI.logger.warn("Provider #{prov_name} failed: #{e.message}")
          next
        end

        raise last_error || Providers::EmbeddingProvider::EmbeddingError.new('All providers failed')
      end

      # Get or create provider instance
      def get_provider(name)
        return @providers[name] if @providers[name]

        @mutex.synchronize do
          # Double-check pattern for thread safety
          return @providers[name] if @providers[name]

          provider_config = @config[:providers][name] || {}
          @providers[name] = Providers::EmbeddingProvider.create(name, **provider_config)
        end
      end

      # Determine which providers to try
      def determine_providers(requested_provider, fallback_providers)
        if requested_provider
          providers = [requested_provider]
          providers.concat(fallback_providers) if fallback_providers
          providers.concat(@config[:fallback_providers] - providers)
        else
          [@config[:default_provider]].concat(@config[:fallback_providers])
        end

        providers.compact.uniq
      end

      # Load configuration from BlueprintsCLI configuration
      def load_configuration
        config = BlueprintsCLI.configuration

        {
          default_provider: config.fetch(:embedding, :default_provider, default: :informers),
          fallback_providers: config.fetch(:embedding, :fallback_providers, default: [:ruby_llm]),
          providers: {
            informers: {
              model: config.fetch(:embedding, :informers, :model,
                                  default: 'sentence-transformers/all-MiniLM-L6-v2'),
              device: config.fetch(:embedding, :informers, :device, default: 'cpu'),
              quantized: config.fetch(:embedding, :informers, :quantized, default: true),
              max_length: config.fetch(:embedding, :informers, :max_length, default: 512)
            },
            ruby_llm: {
              model: config.fetch(:embedding, :ruby_llm, :model, default: nil),
              provider: config.fetch(:embedding, :ruby_llm, :provider, default: nil)
            }
          }
        }
      end

      # Calculate success rate
      def success_rate
        total = @stats[:total_requests]
        return 0.0 if total.zero?

        (@stats[:successful_requests].to_f / total * 100).round(2)
      end

      # Aggregate cache statistics from all providers
      def aggregate_cache_stats
        total_cache_size = 0
        total_hit_rate = 0.0
        provider_count = 0

        @providers.each_value do |provider|
          next unless provider.respond_to?(:cache_stats)

          stats = provider.cache_stats
          total_cache_size += stats[:size] || 0
          total_hit_rate += stats[:hit_rate] || 0.0
          provider_count += 1
        end

        {
          total_cache_size: total_cache_size,
          average_hit_rate: provider_count > 0 ? (total_hit_rate / provider_count).round(3) : 0.0
        }
      end

      # Update average response time
      def update_response_time(duration)
        current_avg = @stats[:average_response_time]
        total_requests = @stats[:total_requests]

        # Calculate running average
        @stats[:average_response_time] =
          ((current_avg * (total_requests - 1)) + duration) / total_requests
      end
    end
  end
end
