# frozen_string_literal: true

require 'algorithms'

module BlueprintsCLI
  module NLP
    module Processors
      # Abstract base class for NLP processors providing common functionality
      # and data structure optimizations using the algorithms gem
      class BaseProcessor
        include Containers

        attr_reader :cache, :metrics, :trie_index

        def initialize
          @cache = RBTreeMap.new  # Red-Black tree for ordered metadata storage
          @metrics = {}
          @trie_index = Trie.new  # For fast prefix-based lookups
          @priority_queue = PriorityQueue.new { |x, y| x[:score] <=> y[:score] }
          @kd_tree_data = {}      # Will be built as needed for vector operations
        end

        # Abstract method - must be implemented by subclasses
        def process(text)
          raise NotImplementedError, "#{self.class}#process must be implemented"
        end

        # Extract key terms using Trie-based prefix matching
        def extract_key_terms(text, min_length: 3)
          terms = []
          words = tokenize(text)

          words.each do |word|
            next if word.length < min_length

            # Use Trie for efficient prefix matching
            next unless @trie_index.key?(word.downcase)

            terms << {
              term: word,
              canonical: @trie_index[word.downcase],
              score: calculate_term_score(word)
            }
          end

          # Use priority queue to rank terms by relevance
          terms.each { |term| @priority_queue.push(term, term[:score]) }

          # Extract top terms
          top_terms = []
          top_terms << @priority_queue.pop while !@priority_queue.empty? && top_terms.length < 10

          top_terms
        end

        # Build KD-tree for high-dimensional similarity search
        def build_vector_index(embeddings_hash)
          return if embeddings_hash.empty?

          # Convert to format expected by KD-tree
          points = embeddings_hash.transform_values do |embedding|
            # Reduce dimensionality for KD-tree efficiency (first 2 dimensions)
            embedding[0..1] if embedding.is_a?(Array)
          end.compact

          @kd_tree = KDTree.new(points) if points.any?
        end

        # Find nearest neighbors using KD-tree
        def find_similar_vectors(target_vector, k: 5)
          return [] unless @kd_tree && target_vector.is_a?(Array)

          # Use first 2 dimensions for KD-tree search
          search_vector = target_vector[0..1]
          @kd_tree.find_nearest(search_vector, k) || []
        end

        # Cache results using Red-Black tree for ordered access
        def cache_result(key, result, metadata = {})
          cache_entry = {
            result: result,
            timestamp: Time.now,
            metadata: metadata
          }
          @cache[key] = cache_entry

          # Maintain cache size limit
          return unless @cache.size > 1000

          # Remove oldest entries (Red-Black tree maintains order)
          @cache.delete(@cache.min[0])
        end

        # Retrieve cached result
        def get_cached_result(key)
          entry = @cache[key]
          return nil unless entry

          # Check if cache entry is still valid (24 hours)
          if Time.now - entry[:timestamp] < 86_400
            entry[:result]
          else
            @cache.delete(key)
            nil
          end
        end

        # Update metrics
        def update_metrics(operation, duration, success = true)
          @metrics[operation] ||= {
            count: 0,
            total_duration: 0.0,
            success_count: 0,
            avg_duration: 0.0
          }

          @metrics[operation][:count] += 1
          @metrics[operation][:total_duration] += duration
          @metrics[operation][:success_count] += 1 if success
          @metrics[operation][:avg_duration] =
            @metrics[operation][:total_duration] / @metrics[operation][:count]
        end

        private

        # Basic tokenization - to be enhanced by subclasses
        def tokenize(text)
          text.downcase.scan(/\b\w+\b/)
        end

        # Calculate term importance score
        def calculate_term_score(term)
          # Basic scoring - can be enhanced with TF-IDF, etc.
          base_score = term.length.to_f / 10.0
          base_score += 0.5 if term.match?(/[A-Z]/) # Bonus for proper nouns
          base_score
        end
      end
    end
  end
end
