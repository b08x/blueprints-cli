# frozen_string_literal: true

require 'ohm'
require 'json'

module BlueprintsCLI
  module Models
    # Redis Ohm models for intelligent caching of NLP processing results
    # Leverages algorithms gem data structures for optimized storage and retrieval

    # Base cache model with common functionality
    class CacheEntry < Ohm::Model
      attribute :key
      attribute :data
      attribute :metadata
      attribute :created_at
      attribute :last_accessed
      attribute :access_count
      attribute :ttl

      index :key
      index :created_at
      index :last_accessed

      def initialize(attributes = {})
        super
        self.created_at = Time.now.to_f.to_s unless created_at
        self.last_accessed = Time.now.to_f.to_s
        self.access_count = '0' unless access_count
      end

      # Deserialize stored data
      def get_data
        return nil unless data

        JSON.parse(data)
      rescue JSON::ParserError
        data
      end

      # Serialize and store data
      def set_data(value)
        self.data = value.is_a?(String) ? value : JSON.generate(value)
      end

      # Get metadata as hash
      def get_metadata
        return {} unless metadata

        JSON.parse(metadata)
      rescue JSON::ParserError
        {}
      end

      # Set metadata as hash
      def set_metadata(value)
        self.metadata = value.is_a?(String) ? value : JSON.generate(value)
      end

      # Track access for LRU eviction
      def mark_accessed!
        self.last_accessed = Time.now.to_f.to_s
        self.access_count = (access_count.to_i + 1).to_s
        save
      end

      # Check if entry has expired
      def expired?
        return false unless ttl

        Time.now.to_f - created_at.to_f > ttl.to_f
      end

      # Get age in seconds
      def age
        Time.now.to_f - created_at.to_f
      end
    end

    # Specialized cache for SpaCy processing results
    class SpacyCache < CacheEntry
      attribute :model_name
      attribute :text_hash
      attribute :token_count
      attribute :entity_count
      attribute :processing_time

      index :model_name
      index :text_hash
      index :token_count
      index :entity_count

      # Create cache entry for SpaCy results
      def self.store_result(text, model_name, result, processing_time = 0)
        text_hash = Digest::MD5.hexdigest(text)

        cache_entry = create(
          key: "spacy_#{model_name}_#{text_hash}",
          text_hash: text_hash,
          model_name: model_name,
          token_count: result[:tokens]&.length&.to_s || '0',
          entity_count: result[:entities]&.length&.to_s || '0',
          processing_time: processing_time.to_s,
          ttl: '86400' # 24 hours
        )

        cache_entry.set_data(result)
        cache_entry.set_metadata({
                                   text_length: text.length,
                                   complexity_score: calculate_complexity(result),
                                   cached_at: Time.now.iso8601
                                 })

        cache_entry.save
        cache_entry
      end

      # Retrieve cached SpaCy result
      def self.get_result(text, model_name)
        text_hash = Digest::MD5.hexdigest(text)
        key = "spacy_#{model_name}_#{text_hash}"

        entry = find(key: key).first
        return nil unless entry && !entry.expired?

        entry.mark_accessed!
        entry.get_data
      end

      # Clean up expired entries
      def self.cleanup_expired
        all.each do |entry|
          entry.delete if entry.expired?
        end
      end

      # Get statistics for SpaCy cache
      def self.statistics
        entries = all.to_a
        {
          total_entries: entries.length,
          avg_processing_time: entries.map { |e| e.processing_time.to_f }.sum / entries.length,
          avg_token_count: entries.map { |e| e.token_count.to_i }.sum / entries.length,
          avg_entity_count: entries.map { |e| e.entity_count.to_i }.sum / entries.length,
          models_used: entries.map(&:model_name).uniq,
          hit_rate: calculate_hit_rate(entries)
        }
      end

      def self.calculate_complexity(result)
        complexity = 0.0
        complexity += (result[:entities]&.length || 0) * 0.1
        complexity += (result[:dependencies]&.length || 0) * 0.05
        complexity += (result[:noun_phrases]&.length || 0) * 0.08
        complexity.round(3)
      end

      def self.calculate_hit_rate(entries)
        return 0.0 if entries.empty?

        total_accesses = entries.sum { |e| e.access_count.to_i }
        return 0.0 if total_accesses == 0

        (entries.length.to_f / total_accesses * 100).round(2)
      end
    end

    # Specialized cache for Linguistics processing results
    class LinguisticsCache < CacheEntry
      attribute :text_hash
      attribute :word_count
      attribute :morphology_count
      attribute :concept_count
      attribute :semantic_density

      index :text_hash
      index :word_count
      index :concept_count
      index :semantic_density

      # Store linguistics processing result
      def self.store_result(text, result, processing_time = 0)
        text_hash = Digest::MD5.hexdigest(text)

        cache_entry = create(
          key: "linguistics_#{text_hash}",
          text_hash: text_hash,
          word_count: (result[:morphology]&.length || 0).to_s,
          morphology_count: (result[:morphology]&.length || 0).to_s,
          concept_count: (result[:concepts]&.length || 0).to_s,
          semantic_density: (result.dig(:complexity_metrics, :semantic_density) || 0.0).to_s,
          processing_time: processing_time.to_s,
          ttl: '86400'
        )

        cache_entry.set_data(result)
        cache_entry.set_metadata({
                                   text_length: text.length,
                                   vocabulary_richness: result.dig(:complexity_metrics,
                                                                   :vocabulary_richness),
                                   lexical_diversity: result.dig(:complexity_metrics,
                                                                 :lexical_diversity),
                                   cached_at: Time.now.iso8601
                                 })

        cache_entry.save
        cache_entry
      end

      # Retrieve cached linguistics result
      def self.get_result(text)
        text_hash = Digest::MD5.hexdigest(text)
        key = "linguistics_#{text_hash}"

        entry = find(key: key).first
        return nil unless entry && !entry.expired?

        entry.mark_accessed!
        entry.get_data
      end

      # Find entries by semantic density range
      def self.by_semantic_density(min_density, max_density)
        all.select do |entry|
          density = entry.semantic_density.to_f
          density >= min_density && density <= max_density
        end
      end

      # Get top concepts across all cached entries
      def self.top_concepts(limit = 10)
        concept_frequency = Hash.new(0)

        all.each do |entry|
          next if entry.expired?

          result = entry.get_data
          next unless result[:concepts]

          result[:concepts].each do |concept|
            concept_frequency[concept[:word]] += 1
          end
        end

        concept_frequency.sort_by { |_word, freq| -freq }.first(limit)
      end
    end

    # Cache for embedding vectors with KD-tree optimization
    class EmbeddingCache < CacheEntry
      attribute :text_hash
      attribute :provider
      attribute :model_name
      attribute :vector_dimensions
      attribute :similarity_hash

      index :text_hash
      index :provider
      index :model_name
      index :vector_dimensions

      # Store embedding vector
      def self.store_embedding(text, provider, model_name, vector, processing_time = 0)
        text_hash = Digest::MD5.hexdigest(text)
        vector_data = vector.is_a?(Array) ? vector : [vector].flatten

        cache_entry = create(
          key: "embedding_#{provider}_#{model_name}_#{text_hash}",
          text_hash: text_hash,
          provider: provider,
          model_name: model_name,
          vector_dimensions: vector_data.length.to_s,
          similarity_hash: calculate_similarity_hash(vector_data),
          processing_time: processing_time.to_s,
          ttl: '604800' # 7 days
        )

        cache_entry.set_data(vector_data)
        cache_entry.set_metadata({
                                   text_length: text.length,
                                   vector_norm: calculate_vector_norm(vector_data),
                                   cached_at: Time.now.iso8601
                                 })

        cache_entry.save
        cache_entry
      end

      # Retrieve cached embedding
      def self.get_embedding(text, provider, model_name)
        text_hash = Digest::MD5.hexdigest(text)
        key = "embedding_#{provider}_#{model_name}_#{text_hash}"

        entry = find(key: key).first
        return nil unless entry && !entry.expired?

        entry.mark_accessed!
        entry.get_data
      end

      # Find similar embeddings using similarity hash
      def self.find_similar(target_vector, provider, model_name, threshold = 0.8)
        target_hash = calculate_similarity_hash(target_vector)

        candidates = find(provider: provider, model_name: model_name).select do |entry|
          next false if entry.expired?

          # Quick filter by similarity hash
          hash_similarity = jaccard_similarity(target_hash, entry.similarity_hash)
          hash_similarity >= threshold * 0.5 # Loose threshold for candidates
        end

        # Calculate actual cosine similarity for candidates
        similar_entries = []
        candidates.each do |entry|
          cached_vector = entry.get_data
          next unless cached_vector.is_a?(Array)

          similarity = cosine_similarity(target_vector, cached_vector)
          next unless similarity >= threshold

          similar_entries << {
            entry: entry,
            vector: cached_vector,
            similarity: similarity
          }
        end

        similar_entries.sort_by { |item| -item[:similarity] }
      end

      # Build KD-tree index for fast nearest neighbor search
      def self.build_kd_tree_index(provider, model_name)
        require 'algorithms'

        entries = find(provider: provider, model_name: model_name).reject(&:expired?)
        return nil if entries.empty?

        # Prepare points for KD-tree (using first 2 dimensions)
        points = {}
        entries.each do |entry|
          vector = entry.get_data
          next unless vector.is_a?(Array) && vector.length >= 2

          points[entry.id] = [vector[0], vector[1]]
        end

        return nil if points.empty?

        Containers::KDTree.new(points)
      end

      # Calculate a hash for quick similarity filtering
      def self.calculate_similarity_hash(vector)
        return '' unless vector.is_a?(Array)

        # Create hash based on vector quantization
        quantized = vector.map { |v| (v * 10).round }
        Digest::MD5.hexdigest(quantized.join(','))[0..7]
      end

      # Calculate vector norm
      def self.calculate_vector_norm(vector)
        return 0.0 unless vector.is_a?(Array)

        Math.sqrt(vector.sum { |v| v * v })
      end

      # Jaccard similarity for similarity hashes
      def self.jaccard_similarity(hash1, hash2)
        return 0.0 if hash1.empty? || hash2.empty?

        chars1 = hash1.chars.to_set
        chars2 = hash2.chars.to_set

        intersection = (chars1 & chars2).size
        union = (chars1 | chars2).size

        return 0.0 if union == 0

        intersection.to_f / union
      end

      # Cosine similarity between vectors
      def self.cosine_similarity(vector1, vector2)
        return 0.0 unless vector1.is_a?(Array) && vector2.is_a?(Array)
        return 0.0 if vector1.length != vector2.length

        dot_product = vector1.zip(vector2).sum { |a, b| a * b }
        norm1 = Math.sqrt(vector1.sum { |v| v * v })
        norm2 = Math.sqrt(vector2.sum { |v| v * v })

        return 0.0 if norm1 == 0 || norm2 == 0

        dot_product / (norm1 * norm2)
      end
    end

    # Cache for complete pipeline results
    class PipelineCache < CacheEntry
      attribute :text_hash
      attribute :pipeline_config
      attribute :processors_used
      attribute :analysis_score
      attribute :feature_count

      index :text_hash
      index :pipeline_config
      index :analysis_score
      index :feature_count

      # Store complete pipeline result
      def self.store_result(text, config, result, processing_time = 0)
        text_hash = Digest::MD5.hexdigest(text)
        config_hash = Digest::MD5.hexdigest(config.to_json)

        cache_entry = create(
          key: "pipeline_#{config_hash}_#{text_hash}",
          text_hash: text_hash,
          pipeline_config: config_hash,
          processors_used: result[:processors_used]&.join(',') || '',
          analysis_score: (result.dig(:analysis_scores, :quality) || 0.0).to_s,
          feature_count: count_features(result).to_s,
          processing_time: processing_time.to_s,
          ttl: '43200' # 12 hours
        )

        cache_entry.set_data(result)
        cache_entry.set_metadata({
                                   text_length: text.length,
                                   completeness: result.dig(:analysis_scores, :completeness),
                                   information_density: result.dig(:analysis_scores,
                                                                   :information_density),
                                   cached_at: Time.now.iso8601
                                 })

        cache_entry.save
        cache_entry
      end

      # Retrieve cached pipeline result
      def self.get_result(text, config)
        text_hash = Digest::MD5.hexdigest(text)
        config_hash = Digest::MD5.hexdigest(config.to_json)
        key = "pipeline_#{config_hash}_#{text_hash}"

        entry = find(key: key).first
        return nil unless entry && !entry.expired?

        entry.mark_accessed!
        entry.get_data
      end

      # Get pipeline performance statistics
      def self.performance_stats
        entries = all.reject(&:expired?)
        return {} if entries.empty?

        {
          total_cached: entries.length,
          avg_processing_time: entries.map { |e| e.processing_time.to_f }.sum / entries.length,
          avg_analysis_score: entries.map { |e| e.analysis_score.to_f }.sum / entries.length,
          avg_feature_count: entries.map { |e| e.feature_count.to_i }.sum / entries.length,
          processor_usage: calculate_processor_usage(entries),
          cache_efficiency: calculate_cache_efficiency(entries)
        }
      end

      def self.count_features(result)
        count = 0
        count += result.dig(:combined_analysis, :keywords)&.length || 0
        count += result.dig(:combined_analysis, :entities)&.length || 0
        count += result.dig(:combined_analysis, :concepts)&.length || 0
        count
      end

      def self.calculate_processor_usage(entries)
        usage = Hash.new(0)
        entries.each do |entry|
          processors = entry.processors_used.split(',')
          processors.each { |processor| usage[processor] += 1 }
        end
        usage
      end

      def self.calculate_cache_efficiency(entries)
        return 0.0 if entries.empty?

        total_accesses = entries.sum { |e| e.access_count.to_i }
        return 0.0 if total_accesses == 0

        cache_hits = entries.count { |e| e.access_count.to_i > 1 }
        (cache_hits.to_f / entries.length * 100).round(2)
      end
    end

    # Cache manager for coordinating all cache operations
    class CacheManager
      include Containers

      def initialize
        @cache_stats = RBTreeMap.new
        @cleanup_interval = 3600 # 1 hour
        @last_cleanup = Time.now
      end

      # Unified cache storage
      def store(cache_type, *args)
        case cache_type
        when :spacy
          SpacyCache.store_result(*args)
        when :linguistics
          LinguisticsCache.store_result(*args)
        when :embedding
          EmbeddingCache.store_embedding(*args)
        when :pipeline
          PipelineCache.store_result(*args)
        else
          raise ArgumentError, "Unknown cache type: #{cache_type}"
        end

        update_stats(cache_type, :store)
        cleanup_if_needed
      end

      # Unified cache retrieval
      def get(cache_type, *args)
        result = case cache_type
                 when :spacy
                   SpacyCache.get_result(*args)
                 when :linguistics
                   LinguisticsCache.get_result(*args)
                 when :embedding
                   EmbeddingCache.get_embedding(*args)
                 when :pipeline
                   PipelineCache.get_result(*args)
                 end

        update_stats(cache_type, result ? :hit : :miss)
        result
      end

      # Get comprehensive cache statistics
      def statistics
        {
          spacy: SpacyCache.statistics,
          linguistics: {
            total_entries: LinguisticsCache.all.length,
            top_concepts: LinguisticsCache.top_concepts(5)
          },
          embedding: {
            total_entries: EmbeddingCache.all.length,
            providers: EmbeddingCache.all.map(&:provider).uniq
          },
          pipeline: PipelineCache.performance_stats,
          cache_operations: @cache_stats.to_h,
          memory_usage: calculate_memory_usage
        }
      end

      # Cleanup expired entries across all caches
      def cleanup_expired!
        SpacyCache.cleanup_expired
        LinguisticsCache.all.each { |e| e.delete if e.expired? }
        EmbeddingCache.all.each { |e| e.delete if e.expired? }
        PipelineCache.all.each { |e| e.delete if e.expired? }

        @last_cleanup = Time.now
      end

      # Clear all caches
      def clear_all!
        [SpacyCache, LinguisticsCache, EmbeddingCache, PipelineCache].each do |klass|
          klass.all.each(&:delete)
        end
        @cache_stats.clear
      end

      private

      def update_stats(cache_type, operation)
        key = "#{cache_type}_#{operation}"
        @cache_stats[key] = (@cache_stats[key] || 0) + 1
      end

      def cleanup_if_needed
        return unless Time.now - @last_cleanup > @cleanup_interval

        Thread.new { cleanup_expired! }
      end

      def calculate_memory_usage
        total_entries = 0
        total_entries += SpacyCache.all.length
        total_entries += LinguisticsCache.all.length
        total_entries += EmbeddingCache.all.length
        total_entries += PipelineCache.all.length

        # Rough estimate: 1KB per entry
        "#{total_entries}KB (estimated)"
      end
    end
  end
end
