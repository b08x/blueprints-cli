# frozen_string_literal: true

require_relative 'processors/spacy_processor'
require_relative 'processors/linguistics_processor'
require 'algorithms'

module BlueprintsCLI
  module NLP
    # Builder pattern implementation for constructing NLP processing pipelines
    # Integrates multiple processors with algorithmic optimizations
    class PipelineBuilder
      include Containers

      attr_reader :processors, :pipeline_config, :performance_metrics

      def initialize
        @processors = []
        @pipeline_config = {
          enable_caching: true,
          cache_ttl: 3600,
          parallel_processing: false,
          output_format: :detailed
        }
        @performance_metrics = RBTreeMap.new
        @result_cache = Trie.new
        @processor_priority = PriorityQueue.new { |x, y| x[:priority] <=> y[:priority] }
      end

      # Add SpaCy processor to pipeline
      def with_spacy(model_name: 'en_core_web_sm', priority: 10)
        processor_config = {
          type: :spacy,
          processor: Processors::SpacyProcessor.new(model_name: model_name),
          priority: priority,
          enabled: true
        }

        @processors << processor_config
        @processor_priority.push(processor_config, priority)
        self
      end

      # Add Linguistics processor to pipeline
      def with_linguistics(priority: 20)
        processor_config = {
          type: :linguistics,
          processor: Processors::LinguisticsProcessor.new,
          priority: priority,
          enabled: true
        }

        @processors << processor_config
        @processor_priority.push(processor_config, priority)
        self
      end

      # Configure pipeline settings
      def configure(options = {})
        @pipeline_config.merge!(options)
        self
      end

      # Enable result caching
      def with_caching(ttl: 3600)
        @pipeline_config[:enable_caching] = true
        @pipeline_config[:cache_ttl] = ttl
        self
      end

      # Enable parallel processing of processors
      def with_parallel_processing
        @pipeline_config[:parallel_processing] = true
        self
      end

      # Set output format (detailed, summary, minimal)
      def output_format(format)
        @pipeline_config[:output_format] = format
        self
      end

      # Build and return the configured pipeline
      def build
        raise 'No processors configured' if @processors.empty?

        # Sort processors by priority using the priority queue
        ordered_processors = []
        temp_queue = @processor_priority.dup

        ordered_processors << temp_queue.pop until temp_queue.empty?

        Pipeline.new(ordered_processors, @pipeline_config)
      end
    end

    # Main NLP Pipeline class that orchestrates multiple processors
    class Pipeline
      include Containers

      attr_reader :processors, :config, :metrics

      def initialize(processors, config)
        @processors = processors
        @config = config
        @metrics = RBTreeMap.new
        @result_cache = Trie.new if config[:enable_caching]
        @hybrid_results = {}
      end

      # Process text through the entire pipeline
      def process(text)
        start_time = Time.now

        begin
          # Check cache if enabled
          if @config[:enable_caching] && cached_result = get_cached_result(text)
            return cached_result
          end

          # Process through each processor
          results = if @config[:parallel_processing]
                      process_parallel(text)
                    else
                      process_sequential(text)
                    end

          # Merge and optimize results
          final_result = merge_results(results, text)

          # Cache result if enabled
          cache_result(text, final_result) if @config[:enable_caching]

          # Update performance metrics
          duration = Time.now - start_time
          update_metrics(:pipeline_processing, duration, final_result)

          format_output(final_result)
        rescue StandardError => e
          duration = Time.now - start_time
          update_metrics(:pipeline_processing, duration, nil, error: e.message)

          {
            error: e.message,
            partial_results: @hybrid_results,
            processing_time: duration
          }
        end
      end

      # Get processing statistics
      def get_statistics
        stats = {}

        @metrics.each do |key, value|
          stats[key] = {
            total_calls: value[:count],
            avg_duration: value[:avg_duration],
            success_rate: value[:success_count].to_f / value[:count],
            total_duration: value[:total_duration]
          }
        end

        stats
      end

      # Build hybrid search index from processed results
      def build_search_index(processed_texts)
        search_index = {
          trie: Trie.new,
          kd_tree_points: {},
          priority_rankings: PriorityQueue.new { |x, y| x[:relevance] <=> y[:relevance] }
        }

        processed_texts.each_with_index do |(text_id, results), _index|
          # Index keywords in Trie for fast prefix search
          if results[:spacy] && results[:spacy][:keywords]
            results[:spacy][:keywords].each do |keyword|
              search_index[:trie][keyword[:text].downcase] = text_id
            end
          end

          # Index concepts in Trie
          if results[:linguistics] && results[:linguistics][:concepts]
            results[:linguistics][:concepts].each do |concept|
              search_index[:trie][concept[:word].downcase] = text_id
            end
          end

          # Build semantic vectors for KD-tree
          if results[:semantic_vector]
            search_index[:kd_tree_points][text_id] = results[:semantic_vector][0..1] # 2D for KD-tree
          end

          # Add to priority queue with relevance score
          relevance_score = calculate_relevance_score(results)
          search_index[:priority_rankings].push(
            { text_id: text_id, results: results, relevance: relevance_score },
            relevance_score
          )
        end

        # Build KD-tree if we have vector data
        if search_index[:kd_tree_points].any?
          search_index[:kd_tree] = KDTree.new(search_index[:kd_tree_points])
        end

        search_index
      end

      # Search using hybrid approach (Trie + KD-tree + Priority Queue)
      def hybrid_search(query, search_index, options = {})
        results = {
          prefix_matches: [],
          semantic_matches: [],
          ranked_results: []
        }

        # Prefix search using Trie
        query_words = query.downcase.split
        query_words.each do |word|
          if search_index[:trie].has_key?(word)
            results[:prefix_matches] << {
              word: word,
              text_id: search_index[:trie][word],
              match_type: 'exact'
            }
          else
            # Wildcard search for partial matches
            wildcard_matches = search_index[:trie].wildcard("#{word}*")
            wildcard_matches.each do |match|
              next unless search_index[:trie].has_key?(match)

              results[:prefix_matches] << {
                word: match,
                text_id: search_index[:trie][match],
                match_type: 'partial'
              }
            end
          end
        end

        # Semantic search using KD-tree (if query has vector representation)
        if options[:query_vector] && search_index[:kd_tree]
          nearest_neighbors = search_index[:kd_tree].find_nearest(
            options[:query_vector][0..1],
            options[:k] || 5
          )

          nearest_neighbors.each do |distance, text_id|
            results[:semantic_matches] << {
              text_id: text_id,
              distance: distance,
              similarity: 1.0 / (1.0 + distance) # Convert distance to similarity
            }
          end
        end

        # Get top-ranked results from priority queue
        temp_queue = search_index[:priority_rankings].dup
        rank_count = 0

        while !temp_queue.empty? && rank_count < (options[:max_results] || 10)
          ranked_item = temp_queue.pop
          results[:ranked_results] << ranked_item
          rank_count += 1
        end

        # Combine and deduplicate results
        combine_search_results(results, options)
      end

      private

      def process_sequential(text)
        results = {}

        @processors.each do |processor_config|
          next unless processor_config[:enabled]

          processor_type = processor_config[:type]
          processor = processor_config[:processor]

          begin
            result = processor.process(text)
            results[processor_type] = result
            @hybrid_results[processor_type] = result
          rescue StandardError => e
            results[processor_type] = { error: e.message }
          end
        end

        results
      end

      def process_parallel(text)
        # NOTE: In a real implementation, you'd use threads or processes
        # For now, we'll simulate parallel processing
        results = {}

        @processors.each do |processor_config|
          next unless processor_config[:enabled]

          processor_type = processor_config[:type]
          processor = processor_config[:processor]

          # Simulate parallel processing
          Thread.new do
            result = processor.process(text)
            results[processor_type] = result
          rescue StandardError => e
            results[processor_type] = { error: e.message }
          end
        end

        # Wait for all threads to complete (simplified)
        sleep(0.1) # In real implementation, use proper thread management

        results
      end

      def merge_results(results, original_text)
        merged = {
          original_text: original_text,
          processing_timestamp: Time.now.iso8601,
          processors_used: results.keys,
          combined_analysis: {}
        }

        # Merge results from different processors
        results.each do |processor_type, result|
          merged[processor_type] = result

          # Extract common elements for combined analysis
          if result[:keywords]
            merged[:combined_analysis][:keywords] ||= []
            merged[:combined_analysis][:keywords].concat(result[:keywords])
          end

          if result[:entities]
            merged[:combined_analysis][:entities] ||= []
            merged[:combined_analysis][:entities].concat(result[:entities])
          end

          if result[:concepts]
            merged[:combined_analysis][:concepts] ||= []
            merged[:combined_analysis][:concepts].concat(result[:concepts])
          end
        end

        # Deduplicate and rank combined results
        if merged[:combined_analysis][:keywords]
          merged[:combined_analysis][:keywords] = deduplicate_and_rank_keywords(
            merged[:combined_analysis][:keywords]
          )
        end

        # Generate semantic vector for the entire analysis
        merged[:semantic_vector] = generate_semantic_vector(merged)

        # Calculate overall analysis scores
        merged[:analysis_scores] = calculate_analysis_scores(merged)

        merged
      end

      def deduplicate_and_rank_keywords(keywords)
        # Use Red-Black tree to maintain ordered unique keywords
        keyword_map = RBTreeMap.new

        keywords.each do |keyword|
          key = keyword[:text] || keyword[:word] || keyword.to_s

          if keyword_map.has_key?(key)
            # Merge scores if duplicate
            existing = keyword_map[key]
            existing[:score] = [existing[:score], keyword[:score] || 0].max
          else
            keyword_map[key] = keyword
          end
        end

        # Convert back to array and sort by score
        unique_keywords = keyword_map.values.sort_by { |k| -(k[:score] || 0) }
        unique_keywords.first(20) # Limit to top 20
      end

      def generate_semantic_vector(merged_results)
        # Simple semantic vector based on analysis features
        vector = []

        # Feature 1: Keyword density
        keyword_count = merged_results.dig(:combined_analysis, :keywords)&.length || 0
        vector << (keyword_count.to_f / 100.0)

        # Feature 2: Entity density
        entity_count = merged_results.dig(:combined_analysis, :entities)&.length || 0
        vector << (entity_count.to_f / 50.0)

        # Feature 3: Concept complexity
        concept_count = merged_results.dig(:combined_analysis, :concepts)&.length || 0
        vector << (concept_count.to_f / 30.0)

        # Feature 4: Linguistic complexity (if available)
        if merged_results[:linguistics] && merged_results[:linguistics][:complexity_metrics]
          complexity = merged_results[:linguistics][:complexity_metrics]
          (vector << complexity[:lexical_diversity]) || 0.0
        else
          vector << 0.0
        end

        vector
      end

      def calculate_analysis_scores(merged_results)
        scores = {}

        # Information density score
        total_features = 0
        total_features += merged_results.dig(:combined_analysis, :keywords)&.length || 0
        total_features += merged_results.dig(:combined_analysis, :entities)&.length || 0
        total_features += merged_results.dig(:combined_analysis, :concepts)&.length || 0

        text_length = merged_results[:original_text].length
        scores[:information_density] =
          text_length > 0 ? total_features.to_f / text_length * 1000 : 0

        # Processing completeness score
        expected_processors = @processors.count { |p| p[:enabled] }
        actual_processors = merged_results[:processors_used].length
        scores[:completeness] = actual_processors.to_f / expected_processors

        # Quality score (based on successful extractions)
        quality_indicators = 0
        quality_indicators += 1 if merged_results.dig(:combined_analysis, :keywords)&.any?
        quality_indicators += 1 if merged_results.dig(:combined_analysis, :entities)&.any?
        quality_indicators += 1 if merged_results.dig(:combined_analysis, :concepts)&.any?
        scores[:quality] = quality_indicators.to_f / 3.0

        scores
      end

      def calculate_relevance_score(results)
        score = 0.0

        # Score based on extracted features
        if results[:spacy]
          score += (results[:spacy][:keywords]&.length || 0) * 0.1
          score += (results[:spacy][:entities]&.length || 0) * 0.2
        end

        if results[:linguistics]
          score += (results[:linguistics][:concepts]&.length || 0) * 0.15
          score += (results[:linguistics][:complexity_metrics]&.dig(:semantic_density) || 0) * 0.3
        end

        # Bonus for analysis completeness
        score += results[:analysis_scores][:completeness] * 0.25 if results[:analysis_scores]

        score.clamp(0.0, 1.0)
      end

      def combine_search_results(results, options)
        combined = {}
        text_ids = Set.new

        # Collect all unique text IDs
        results[:prefix_matches].each { |match| text_ids << match[:text_id] }
        results[:semantic_matches].each { |match| text_ids << match[:text_id] }
        results[:ranked_results].each { |result| text_ids << result[:text_id] }

        # Score each text ID based on different match types
        text_ids.each do |text_id|
          score = 0.0
          match_types = []

          # Prefix match score
          prefix_matches = results[:prefix_matches].select { |m| m[:text_id] == text_id }
          if prefix_matches.any?
            exact_matches = prefix_matches.count { |m| m[:match_type] == 'exact' }
            partial_matches = prefix_matches.count { |m| m[:match_type] == 'partial' }
            score += (exact_matches * 0.5) + (partial_matches * 0.2)
            match_types << 'lexical'
          end

          # Semantic match score
          semantic_match = results[:semantic_matches].find { |m| m[:text_id] == text_id }
          if semantic_match
            score += semantic_match[:similarity] * 0.4
            match_types << 'semantic'
          end

          # Ranking score
          ranked_result = results[:ranked_results].find { |r| r[:text_id] == text_id }
          if ranked_result
            score += ranked_result[:relevance] * 0.3
            match_types << 'ranked'
          end

          combined[text_id] = {
            text_id: text_id,
            total_score: score,
            match_types: match_types.uniq,
            details: {
              prefix_matches: prefix_matches,
              semantic_match: semantic_match,
              ranked_result: ranked_result
            }
          }
        end

        # Sort by total score and return top results
        sorted_results = combined.values.sort_by { |r| -r[:total_score] }
        sorted_results.first(options[:max_results] || 10)
      end

      def format_output(result)
        case @config[:output_format]
        when :minimal
          {
            keywords: result.dig(:combined_analysis, :keywords)&.first(5),
            entities: result.dig(:combined_analysis, :entities)&.first(3),
            summary_scores: result[:analysis_scores]
          }
        when :summary
          {
            processors_used: result[:processors_used],
            combined_analysis: result[:combined_analysis],
            analysis_scores: result[:analysis_scores],
            processing_timestamp: result[:processing_timestamp]
          }
        else # :detailed
          result
        end
      end

      def get_cached_result(text)
        return nil unless @result_cache

        cache_key = generate_cache_key(text)
        @result_cache[cache_key] if @result_cache.has_key?(cache_key)
      end

      def cache_result(text, result)
        return unless @result_cache

        cache_key = generate_cache_key(text)
        @result_cache[cache_key] = result
      end

      def generate_cache_key(text)
        "pipeline_#{Digest::MD5.hexdigest(text[0..200])}"
      end

      def update_metrics(operation, duration, _result, error: nil)
        @metrics[operation] ||= {
          count: 0,
          total_duration: 0.0,
          success_count: 0,
          avg_duration: 0.0
        }

        @metrics[operation][:count] += 1
        @metrics[operation][:total_duration] += duration
        @metrics[operation][:success_count] += 1 unless error
        @metrics[operation][:avg_duration] =
          @metrics[operation][:total_duration] / @metrics[operation][:count]
      end
    end
  end
end
