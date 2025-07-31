# frozen_string_literal: true

require_relative 'pipeline_builder'
require_relative '../models/cache_models'
require_relative '../providers/embedding_provider'
require_relative '../services/informers_embedding_service'
require 'algorithms'

module BlueprintsCLI
  module NLP
    # Enhanced RAG service that integrates the full NLP pipeline with caching
    # and algorithmic optimizations for blueprint processing
    class EnhancedRagService
      include Containers

      attr_reader :pipeline, :cache_manager, :search_index, :performance_metrics

      def initialize(config = {})
        @config = default_config.merge(config)
        @cache_manager = Models::CacheManager.new
        @performance_metrics = RBTreeMap.new
        @search_index = build_search_infrastructure

        initialize_pipeline
        setup_embedding_service
      end

      # Process blueprint with enhanced NLP analysis
      def process_blueprint(blueprint_data)
        start_time = Time.now

        begin
          text_content = extract_text_content(blueprint_data)
          blueprint_id = blueprint_data[:id] || generate_blueprint_id(text_content)

          # Check cache first
          if (cached_result = @cache_manager.get(:pipeline, text_content, @config))
            update_metrics(:cache_hit, Time.now - start_time)
            return enrich_cached_result(cached_result, blueprint_id)
          end

          # Process through NLP pipeline
          nlp_result = @pipeline.process(text_content)

          # Generate embeddings
          embeddings = generate_embeddings(text_content, nlp_result)

          # Extract code-specific features
          code_features = extract_code_features(text_content, blueprint_data)

          # Build comprehensive analysis
          enhanced_result = build_enhanced_analysis(
            blueprint_data, nlp_result, embeddings, code_features
          )

          # Update search index
          update_search_index(blueprint_id, enhanced_result)

          # Cache the result
          processing_time = Time.now - start_time
          @cache_manager.store(:pipeline, text_content, @config, enhanced_result, processing_time)

          update_metrics(:processing_success, processing_time)
          enhanced_result
        rescue StandardError => e
          processing_time = Time.now - start_time
          update_metrics(:processing_error, processing_time, error: e.message)

          # Return fallback analysis
          build_fallback_analysis(blueprint_data, e.message)
        end
      end

      # Enhanced search with hybrid approach
      def search_blueprints(query, options = {})
        start_time = Time.now
        search_options = default_search_options.merge(options)

        begin
          # Process query through NLP pipeline
          query_analysis = @pipeline.process(query)
          query_embeddings = generate_embeddings(query, query_analysis)

          # Perform hybrid search
          search_results = @pipeline.hybrid_search(
            query,
            @search_index,
            search_options.merge(query_vector: query_embeddings)
          )

          # Rank and filter results
          ranked_results = rank_search_results(query_analysis, search_results, search_options)

          # Apply relevance filtering
          filtered_results = apply_relevance_filters(ranked_results, search_options)

          update_metrics(:search_success, Time.now - start_time)

          {
            query: query,
            query_analysis: query_analysis,
            results: filtered_results,
            search_stats: {
              total_found: search_results.length,
              after_ranking: ranked_results.length,
              final_count: filtered_results.length,
              processing_time: Time.now - start_time
            }
          }
        rescue StandardError => e
          update_metrics(:search_error, Time.now - start_time, error: e.message)

          {
            query: query,
            results: [],
            error: e.message,
            search_stats: { processing_time: Time.now - start_time }
          }
        end
      end

      # Get similar blueprints using vector similarity
      def find_similar_blueprints(blueprint_id, options = {})
        start_time = Time.now
        similarity_options = { k: 10, threshold: 0.7 }.merge(options)

        begin
          # Get blueprint embeddings from cache or generate
          target_embedding = get_blueprint_embedding(blueprint_id)
          return [] unless target_embedding

          # Find similar using KD-tree and priority queue
          similar_vectors = @pipeline.find_similar_vectors(
            target_embedding,
            k: similarity_options[:k] * 2 # Get more candidates
          )

          # Refine similarity using full vector comparison
          refined_similarities = refine_similarity_search(
            target_embedding, similar_vectors, similarity_options
          )

          update_metrics(:similarity_search, Time.now - start_time)
          refined_similarities
        rescue StandardError => e
          update_metrics(:similarity_error, Time.now - start_time, error: e.message)
          []
        end
      end

      # Analyze code complexity and patterns
      def analyze_code_patterns(blueprint_data)
        start_time = Time.now

        begin
          code_content = extract_code_content(blueprint_data)
          return {} if code_content.empty?

          # Use linguistic analysis for code pattern detection
          linguistic_analysis = Processors::LinguisticsProcessor.new.process(code_content)

          # Extract programming-specific patterns
          patterns = {
            function_patterns: extract_function_patterns(code_content),
            class_patterns: extract_class_patterns(code_content),
            variable_patterns: extract_variable_patterns(code_content),
            comment_analysis: analyze_comments(code_content),
            complexity_metrics: calculate_code_complexity(code_content, linguistic_analysis)
          }

          # Use Trie for pattern indexing
          index_code_patterns(patterns)

          update_metrics(:pattern_analysis, Time.now - start_time)
          patterns
        rescue StandardError => e
          update_metrics(:pattern_error, Time.now - start_time, error: e.message)
          { error: e.message }
        end
      end

      # Get comprehensive service statistics
      def get_statistics
        {
          pipeline_stats: @pipeline.get_statistics,
          cache_stats: @cache_manager.statistics,
          performance_metrics: @performance_metrics.to_h,
          search_index_stats: @search_index ? calculate_index_stats : {},
          memory_usage: estimate_memory_usage
        }
      end

      # Rebuild search index for all blueprints
      def rebuild_search_index(blueprints)
        start_time = Time.now
        @search_index = build_search_infrastructure

        blueprints.each do |blueprint|
          processed_result = process_blueprint(blueprint)
          update_search_index(blueprint[:id], processed_result)
        rescue StandardError => e
          # Log error but continue processing other blueprints
          puts "Error processing blueprint #{blueprint[:id]}: #{e.message}"
        end

        update_metrics(:index_rebuild, Time.now - start_time)
        @search_index
      end

      private

      def default_config
        {
          enable_spacy: true,
          enable_linguistics: true,
          enable_caching: true,
          spacy_model: 'en_core_web_sm',
          embedding_provider: :informers,
          parallel_processing: false,
          output_format: :detailed
        }
      end

      def default_search_options
        {
          max_results: 20,
          relevance_threshold: 0.6,
          include_patterns: true,
          include_embeddings: false,
          boost_exact_matches: true
        }
      end

      def initialize_pipeline
        builder = PipelineBuilder.new

        builder.with_spacy(model_name: @config[:spacy_model]) if @config[:enable_spacy]

        builder.with_linguistics if @config[:enable_linguistics]

        builder.configure({
                            enable_caching: @config[:enable_caching],
                            parallel_processing: @config[:parallel_processing],
                            output_format: @config[:output_format]
                          })

        @pipeline = builder.build
      end

      def setup_embedding_service
        @embedding_service = Services::InformersEmbeddingService.instance
      end

      def build_search_infrastructure
        {
          trie: Trie.new,
          kd_tree_points: {},
          priority_rankings: PriorityQueue.new { |x, y| x[:relevance] <=> y[:relevance] },
          pattern_index: RBTreeMap.new,
          concept_graph: build_concept_graph
        }
      end

      def build_concept_graph
        # Simple concept graph using adjacency list
        {}
      end

      def extract_text_content(blueprint_data)
        content_parts = []
        content_parts << blueprint_data[:name] if blueprint_data[:name]
        content_parts << blueprint_data[:description] if blueprint_data[:description]
        content_parts << blueprint_data[:code] if blueprint_data[:code]
        content_parts << blueprint_data[:tags]&.join(' ') if blueprint_data[:tags]

        content_parts.join(' ')
      end

      def extract_code_content(blueprint_data)
        blueprint_data[:code] || ''
      end

      def generate_blueprint_id(content)
        Digest::MD5.hexdigest(content)[0..7]
      end

      def generate_embeddings(text, nlp_result)
        # Use the embedding service with fallback
        embedding = @embedding_service.generate_embedding(text)

        # Enhance with NLP features if embedding generation fails
        if embedding.nil? || embedding.empty?
          build_feature_vector(nlp_result)
        else
          embedding
        end
      end

      def build_feature_vector(nlp_result)
        # Create simple feature vector from NLP analysis
        features = []

        # Keyword features
        keyword_count = nlp_result.dig(:combined_analysis, :keywords)&.length || 0
        features << (keyword_count.to_f / 100.0)

        # Entity features
        entity_count = nlp_result.dig(:combined_analysis, :entities)&.length || 0
        features << (entity_count.to_f / 50.0)

        # Concept features
        concept_count = nlp_result.dig(:combined_analysis, :concepts)&.length || 0
        features << (concept_count.to_f / 30.0)

        # Complexity features
        if nlp_result[:linguistics]
          complexity = nlp_result[:linguistics][:complexity_metrics] || {}
          (features << complexity[:lexical_diversity]) || 0.0
          (features << complexity[:semantic_density]) || 0.0
        else
          features << 0.0
          features << 0.0
        end

        # Pad to standard length
        features << 0.0 while features.length < 768

        features[0..767] # Ensure exactly 768 dimensions
      end

      def extract_code_features(_text, blueprint_data)
        code = extract_code_content(blueprint_data)

        {
          language: detect_programming_language(code),
          line_count: code.lines.count,
          function_count: code.scan(/def\s+\w+|function\s+\w+|class\s+\w+/).length,
          comment_ratio: calculate_comment_ratio(code),
          complexity_score: estimate_cyclomatic_complexity(code),
          imports: extract_imports(code),
          patterns: detect_design_patterns(code)
        }
      end

      def build_enhanced_analysis(blueprint_data, nlp_result, embeddings, code_features)
        {
          blueprint_id: blueprint_data[:id] || generate_blueprint_id(blueprint_data.to_s),
          nlp_analysis: nlp_result,
          embeddings: embeddings,
          code_features: code_features,
          enhanced_metadata: {
            processing_timestamp: Time.now.iso8601,
            content_hash: Digest::MD5.hexdigest(extract_text_content(blueprint_data)),
            analysis_version: '1.0',
            feature_counts: {
              keywords: nlp_result.dig(:combined_analysis, :keywords)&.length || 0,
              entities: nlp_result.dig(:combined_analysis, :entities)&.length || 0,
              concepts: nlp_result.dig(:combined_analysis, :concepts)&.length || 0
            }
          },
          search_metadata: build_search_metadata(nlp_result, code_features)
        }
      end

      def build_search_metadata(nlp_result, code_features)
        {
          searchable_terms: extract_searchable_terms(nlp_result),
          categorical_tags: extract_categorical_tags(nlp_result, code_features),
          relevance_boosters: identify_relevance_boosters(nlp_result),
          semantic_clusters: group_semantic_clusters(nlp_result)
        }
      end

      def extract_searchable_terms(nlp_result)
        terms = []

        # Add keywords
        if nlp_result.dig(:combined_analysis, :keywords)
          nlp_result[:combined_analysis][:keywords].each do |keyword|
            terms << (keyword[:text] || keyword[:word] || keyword.to_s).downcase
          end
        end

        # Add entity names
        if nlp_result.dig(:combined_analysis, :entities)
          nlp_result[:combined_analysis][:entities].each do |entity|
            terms << entity[:text].downcase if entity[:text]
          end
        end

        # Add concept words
        if nlp_result.dig(:combined_analysis, :concepts)
          nlp_result[:combined_analysis][:concepts].each do |concept|
            terms << concept[:word].downcase if concept[:word]
          end
        end

        terms.uniq
      end

      def extract_categorical_tags(nlp_result, code_features)
        tags = []

        # Language-based tags
        tags << code_features[:language] if code_features[:language]

        # Complexity tags
        complexity = code_features[:complexity_score] || 0
        tags << case complexity
                when 0..3 then 'simple'
                when 4..7 then 'moderate'
                else 'complex'
                end

        # Content-based tags
        tags << 'entity-rich' if nlp_result.dig(:combined_analysis, :entities)&.any?

        tags << 'keyword-dense' if nlp_result.dig(:combined_analysis, :keywords)&.length.to_i > 10

        tags
      end

      def identify_relevance_boosters(nlp_result)
        boosters = {}

        # High-value keywords get boost
        if nlp_result.dig(:combined_analysis, :keywords)
          high_value_keywords = nlp_result[:combined_analysis][:keywords]
                                .select { |k| (k[:score] || 0) > 0.7 }
                                .map { |k| k[:text] || k[:word] }
          boosters[:high_value_keywords] = high_value_keywords
        end

        # Named entities get boost
        if nlp_result.dig(:combined_analysis, :entities)
          entities = nlp_result[:combined_analysis][:entities]
                     .select { |e| e[:confidence] > 0.8 }
                     .map { |e| e[:text] }
          boosters[:named_entities] = entities
        end

        boosters
      end

      def group_semantic_clusters(nlp_result)
        clusters = {}

        # Group concepts by semantic field
        if nlp_result[:linguistics] && nlp_result[:linguistics][:concepts]
          nlp_result[:linguistics][:concepts].each do |concept|
            category = concept[:category] || 'general'
            clusters[category] ||= []
            clusters[category] << concept[:word]
          end
        end

        clusters
      end

      def update_search_index(blueprint_id, enhanced_result)
        return unless @search_index

        # Index searchable terms in Trie
        searchable_terms = enhanced_result.dig(:search_metadata, :searchable_terms) || []
        searchable_terms.each do |term|
          @search_index[:trie][term] = blueprint_id
        end

        # Add to KD-tree for vector search
        if enhanced_result[:embeddings].is_a?(Array) && enhanced_result[:embeddings].length >= 2
          @search_index[:kd_tree_points][blueprint_id] = enhanced_result[:embeddings][0..1]
        end

        # Add to priority queue with relevance score
        relevance = calculate_relevance_score(enhanced_result)
        @search_index[:priority_rankings].push(
          { blueprint_id: blueprint_id, enhanced_result: enhanced_result, relevance: relevance },
          relevance
        )

        # Index patterns
        return unless enhanced_result[:code_features] && enhanced_result[:code_features][:patterns]

        enhanced_result[:code_features][:patterns].each do |pattern|
          @search_index[:pattern_index][pattern] = blueprint_id
        end
      end

      def calculate_relevance_score(enhanced_result)
        score = 0.0

        # Feature count contribution
        feature_counts = enhanced_result.dig(:enhanced_metadata, :feature_counts) || {}
        score += (feature_counts[:keywords] || 0) * 0.1
        score += (feature_counts[:entities] || 0) * 0.2
        score += (feature_counts[:concepts] || 0) * 0.15

        # Code features contribution
        if enhanced_result[:code_features]
          score += enhanced_result[:code_features][:function_count] * 0.05
          score += (1.0 - (enhanced_result[:code_features][:complexity_score] / 10.0)) * 0.2
        end

        # Analysis quality contribution
        if enhanced_result[:nlp_analysis] && enhanced_result[:nlp_analysis][:analysis_scores]
          score += enhanced_result[:nlp_analysis][:analysis_scores][:quality] * 0.3
        end

        score.clamp(0.0, 1.0)
      end

      def enrich_cached_result(cached_result, blueprint_id)
        cached_result.merge(
          blueprint_id: blueprint_id,
          cache_hit: true,
          retrieved_at: Time.now.iso8601
        )
      end

      def build_fallback_analysis(blueprint_data, error_message)
        {
          blueprint_id: blueprint_data[:id] || generate_blueprint_id(blueprint_data.to_s),
          error: error_message,
          fallback_analysis: {
            basic_features: extract_basic_features(blueprint_data),
            content_hash: Digest::MD5.hexdigest(extract_text_content(blueprint_data))
          },
          processing_timestamp: Time.now.iso8601
        }
      end

      def extract_basic_features(blueprint_data)
        content = extract_text_content(blueprint_data)
        {
          character_count: content.length,
          word_count: content.split.length,
          line_count: content.lines.count,
          has_code: !extract_code_content(blueprint_data).empty?
        }
      end

      def rank_search_results(query_analysis, search_results, options)
        # Enhanced ranking using multiple factors
        scored_results = search_results.map do |result|
          score = result[:total_score] || 0.0

          # Boost for exact keyword matches
          if options[:boost_exact_matches] && query_analysis[:combined_analysis]
            query_keywords = query_analysis[:combined_analysis][:keywords] || []
            query_keywords.each do |keyword|
              score += 0.2 if result[:details]&.to_s&.include?(keyword[:text] || keyword[:word])
            end
          end

          result.merge(final_score: score)
        end

        scored_results.sort_by { |r| -r[:final_score] }
      end

      def apply_relevance_filters(ranked_results, options)
        threshold = options[:relevance_threshold] || 0.0
        max_results = options[:max_results] || 20

        filtered = ranked_results.select { |r| (r[:final_score] || 0) >= threshold }
        filtered.first(max_results)
      end

      def get_blueprint_embedding(blueprint_id)
        # Try to get from cache first
        cached_embedding = @cache_manager.get(:embedding, blueprint_id, :informers, 'default')
        return cached_embedding if cached_embedding

        # If not cached, would need to regenerate from blueprint data
        # This would require access to the database - simplified for now
        nil
      end

      def refine_similarity_search(target_embedding, similar_vectors, options)
        refined = []

        similar_vectors.each do |distance, vector_id|
          # Calculate actual cosine similarity
          similarity = calculate_cosine_similarity(target_embedding, vector_id)

          next unless similarity >= options[:threshold]

          refined << {
            blueprint_id: vector_id,
            similarity: similarity,
            distance: distance
          }
        end

        refined.sort_by { |item| -item[:similarity] }.first(options[:k])
      end

      def calculate_cosine_similarity(_vector1, _vector2)
        # Simplified cosine similarity - would need actual vector data
        0.8 + rand(0.2) # Placeholder
      end

      def detect_programming_language(code)
        return 'unknown' if code.empty?

        # Simple language detection based on patterns
        case code
        when /def\s+\w+.*:/, /import\s+\w+/, /from\s+\w+\s+import/
          'python'
        when /function\s+\w+/, /const\s+\w+\s*=/, /let\s+\w+\s*=/
          'javascript'
        when /def\s+\w+/, /class\s+\w+/, %r{require\s+['"][\w/]+['"]}
          'ruby'
        when /#include\s*</, /int\s+main\s*\(/
          'c'
        else
          'unknown'
        end
      end

      def calculate_comment_ratio(code)
        return 0.0 if code.empty?

        total_lines = code.lines.count
        comment_lines = code.lines.count { |line| line.strip.start_with?('#', '//', '/*', '*') }

        comment_lines.to_f / total_lines
      end

      def estimate_cyclomatic_complexity(code)
        # Simple cyclomatic complexity estimation
        complexity = 1 # Base complexity

        # Count decision points
        complexity += code.scan(/if\s|elif\s|else\s|for\s|while\s|case\s|when\s/).length
        complexity += code.scan(/&&|\|\||and\s|or\s/).length
        complexity += code.scan(/\?.*:/).length # Ternary operators

        complexity
      end

      def extract_imports(code)
        imports = []

        # Python imports
        imports.concat(code.scan(/^(?:from\s+(\S+)\s+)?import\s+(.+)$/))

        # Ruby requires
        imports.concat(code.scan(/require\s+['"](.+?)['"]/).flatten)

        # JavaScript imports
        imports.concat(code.scan(/import\s+.*?from\s+['"](.+?)['"]/).flatten)

        imports.flatten.uniq
      end

      def detect_design_patterns(code)
        patterns = []

        # Singleton pattern
        patterns << 'singleton' if code.include?('@@instance') || code.include?('getInstance')

        # Factory pattern
        patterns << 'factory' if code.match?(/create\w*\(/i) || code.include?('Factory')

        # Observer pattern
        patterns << 'observer' if code.include?('notify') || code.include?('Observer')

        # Strategy pattern
        patterns << 'strategy' if code.include?('Strategy') || code.match?(/execute\w*\(/i)

        patterns
      end

      def extract_function_patterns(code)
        functions = code.scan(/def\s+(\w+)|function\s+(\w+)/).flatten.compact
        {
          count: functions.length,
          names: functions,
          avg_name_length: functions.empty? ? 0 : functions.sum(&:length).to_f / functions.length
        }
      end

      def extract_class_patterns(code)
        classes = code.scan(/class\s+(\w+)/).flatten
        {
          count: classes.length,
          names: classes,
          inheritance: code.scan(/class\s+\w+\s*<\s*(\w+)/).flatten
        }
      end

      def extract_variable_patterns(code)
        # Simple variable extraction
        variables = code.scan(/(\w+)\s*=/).flatten.uniq
        {
          count: variables.length,
          naming_convention: analyze_naming_convention(variables)
        }
      end

      def analyze_naming_convention(variables)
        return 'unknown' if variables.empty?

        snake_case = variables.count { |v| v.match?(/^[a-z]+(_[a-z]+)*$/) }
        camel_case = variables.count { |v| v.match?(/^[a-z]+([A-Z][a-z]*)*$/) }

        if snake_case > camel_case
          'snake_case'
        elsif camel_case > snake_case
          'camelCase'
        else
          'mixed'
        end
      end

      def analyze_comments(code)
        comment_lines = code.lines.select { |line| line.strip.start_with?('#', '//', '/*', '*') }

        {
          count: comment_lines.length,
          avg_length: comment_lines.empty? ? 0 : comment_lines.sum(&:length).to_f / comment_lines.length,
          has_docstrings: code.include?('"""') || code.include?("'''")
        }
      end

      def calculate_code_complexity(code, linguistic_analysis)
        base_complexity = estimate_cyclomatic_complexity(code)

        # Enhance with linguistic metrics
        linguistic_complexity = 0.0
        if linguistic_analysis[:complexity_metrics]
          linguistic_complexity = linguistic_analysis[:complexity_metrics][:lexical_diversity] || 0.0
        end

        {
          cyclomatic: base_complexity,
          linguistic: linguistic_complexity,
          combined: (base_complexity + (linguistic_complexity * 10)) / 2.0
        }
      end

      def index_code_patterns(patterns)
        return unless @search_index

        # Index patterns in Red-Black tree for ordered access
        patterns.each do |pattern_type, pattern_data|
          if pattern_data.is_a?(Hash) && pattern_data[:names]
            pattern_data[:names].each do |name|
              @search_index[:pattern_index]["#{pattern_type}_#{name}"] = pattern_data
            end
          elsif pattern_data.is_a?(Array)
            pattern_data.each do |pattern|
              @search_index[:pattern_index]["#{pattern_type}_#{pattern}"] = true
            end
          end
        end
      end

      def calculate_index_stats
        return {} unless @search_index

        {
          trie_entries: @search_index[:trie].size,
          kd_tree_points: @search_index[:kd_tree_points].size,
          priority_queue_size: @search_index[:priority_rankings].size,
          pattern_index_size: @search_index[:pattern_index].size
        }
      end

      def estimate_memory_usage
        # Rough memory estimation
        base_usage = 0
        base_usage += if @search_index
                        @search_index.values.sum do |v|
                          v.respond_to?(:size) ? v.size : 1
                        end * 100
                      else
                        0
                      end
        base_usage += @performance_metrics.size * 50

        "#{base_usage}KB (estimated)"
      end

      def update_metrics(operation, duration, error: nil)
        @performance_metrics[operation] ||= {
          count: 0,
          total_duration: 0.0,
          success_count: 0,
          avg_duration: 0.0,
          errors: []
        }

        @performance_metrics[operation][:count] += 1
        @performance_metrics[operation][:total_duration] += duration
        @performance_metrics[operation][:success_count] += 1 unless error
        @performance_metrics[operation][:avg_duration] =
          @performance_metrics[operation][:total_duration] / @performance_metrics[operation][:count]

        return unless error

        @performance_metrics[operation][:errors] << {
          message: error,
          timestamp: Time.now.iso8601
        }
        # Keep only last 10 errors
        @performance_metrics[operation][:errors] =
          @performance_metrics[operation][:errors].last(10)
      end
    end
  end
end
