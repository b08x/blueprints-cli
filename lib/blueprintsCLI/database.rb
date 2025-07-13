# frozen_string_literal: true

require 'ruby_llm'
require 'pgvector'
require_relative 'db/interface'
# Temporarily comment out enhanced RAG for testing
# require_relative 'nlp/enhanced_rag_service'
# require_relative 'models/cache_models'
# require_relative 'services/informers_embedding_service'

module BlueprintsCLI
  # Provides a direct database interface for managing "blueprints" (code snippets).
  #
  # This class encapsulates all database operations for blueprints, including
  # standard CRUD actions, category management, and advanced vector-based
  # similarity searches. It uses the Sequel ORM to interact with a PostgreSQL
  # database (requiring the `pgvector` extension for search) and leverages the
  # Google Gemini API to generate text embeddings for semantic search capabilities.
  #
  # Configuration is loaded from the unified configuration system via
  # `BlueprintsCLI::Configuration`, environment variables, or sensible defaults.
  #
  class BlueprintDatabase
    include BlueprintsCLI::Interfaces::DatabaseInterface

    # @!attribute [r] db
    #   @return [Sequel::Database] The active Sequel database connection instance.
    # @!attribute [r] rag_service
    #   @return [BlueprintsCLI::NLP::EnhancedRagService] The enhanced RAG service for NLP processing.
    # @!attribute [r] cache_manager
    #   @return [BlueprintsCLI::Models::CacheManager] The cache manager for intelligent caching.
    attr_reader :db, :rag_service, :cache_manager

    #
    # Initializes the database connection and validates the schema.
    #
    # Connects to the PostgreSQL database using a URL determined by the provided
    # parameter, a configuration file, or environment variables. It also ensures
    # that the necessary tables (`blueprints`, `categories`, `blueprints_categories`)
    # and the `pgvector` extension exist.
    #
    # @param database_url [String, nil] The PostgreSQL connection URL. If nil,
    #   it falls back to `BLUEPRINT_DATABASE_URL` or `DATABASE_URL`
    #   environment variables, or a default local URL.
    #
    # @raise [StandardError] If the database connection fails or a required
    #   table is missing from the schema.
    #
    def initialize(database_url: nil, rag_config: {})
      @database_url = database_url || load_database_url
      @db = connect_to_database
      # Temporarily disable enhanced RAG for testing
      # @cache_manager = Models::CacheManager.new
      # @rag_service = NLP::EnhancedRagService.new(rag_config)

      validate_database_schema

      # Temporarily disable search index rebuilding
      # rebuild_search_index
    end

    #
    # Creates a new blueprint, generates its embedding, and associates categories.
    #
    # This method inserts a new blueprint into the database within a transaction.
    # It automatically generates a vector embedding from the blueprint's name and
    # description using the Gemini API. If categories are provided, they are
    # created if they don't exist and linked to the new blueprint.
    #
    # @param code [String] The code content for the blueprint.
    # @param name [String, nil] A name for the blueprint.
    # @param description [String, nil] A description of the blueprint's purpose.
    # @param categories [Array<String>] A list of category names to associate.
    #
    # @return [Hash, nil] A hash representing the complete blueprint record
    #   (including its new ID and categories), or `nil` if an error occurs.
    #
    # @example
    #   db.create_blueprint(
    #     code: "puts 'Hello, World!'",
    #     name: "Hello World Snippet",
    #     description: "A simple Ruby script to print a greeting.",
    #     categories: ["Ruby", "Examples"]
    #   )
    #   # => {id: 1, code: "...", name: "...", ..., categories: [{id: 1, title: "Ruby"}, ...]}
    #
    def create_blueprint(code:, name: nil, description: nil, categories: [], language: 'ruby', 
                         file_type: '.rb', blueprint_type: 'code', parser_type: 'ruby')
      @db.transaction do
        # Prepare blueprint data for enhanced processing
        blueprint_data = {
          code: code,
          name: name,
          description: description,
          categories: categories
        }

        # Process through enhanced RAG pipeline
        # rag_result = @rag_service.process_blueprint(blueprint_data)

        # Use traditional embedding generation (enhanced RAG disabled)
        content_to_embed = { name: name, description: description }.to_json
        begin
          embedding_result = RubyLLM.embed(content_to_embed)
          # Extract the actual vector array from the result
          embedding_vector = embedding_result.vectors
        rescue RubyLLM::Error => e
          # Fallback to a zero vector if embedding fails
          BlueprintsCLI.logger.warn("RubyLLM embedding failed: #{e.message}, using zero vector")
          embedding_vector = Array.new(768, 0.0)
        rescue => e
          # Handle other errors
          BlueprintsCLI.logger.warn("Embedding generation failed: #{e.message}, using zero vector")
          embedding_vector = Array.new(768, 0.0)
        end

        # Insert blueprint record with enhanced metadata
        blueprint_id = @db[:blueprints].insert(
          code: code,
          name: name,
          description: description,
          language: language,
          file_type: file_type,
          blueprint_type: blueprint_type,
          parser_type: parser_type,
          embedding: Pgvector.encode(embedding_vector),
          # nlp_metadata: rag_result.to_json,
          created_at: Time.now,
          updated_at: Time.now
        )

        # Store in cache for future access (disabled for now)
        # @cache_manager.store(:pipeline, blueprint_data.to_json, @rag_service.config, rag_result)

        # Handle categories if provided
        insert_blueprint_categories(blueprint_id, categories) if categories.any?

        # Update search index (disabled for now)
        # blueprint_data.merge(id: blueprint_id)
        # @rag_service.update_search_index(blueprint_id, rag_result)

        # Return the blueprint
        get_blueprint(blueprint_id)
      end
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error creating blueprint: #{e.message}")
      nil
    end

    #
    # Retrieves a specific blueprint and its associated categories by ID.
    #
    # @param id [Integer] The unique identifier of the blueprint.
    #
    # @return [Hash, nil] A hash containing the blueprint's data and a nested
    #   `:categories` array, or `nil` if no blueprint with that ID is found.
    #
    # @example
    #   blueprint = db.get_blueprint(42)
    #   # => {id: 42, name: "My Blueprint", ..., categories: [...]}
    #
    def get_blueprint(id)
      blueprint = @db[:blueprints].where(id: id).first
      return nil unless blueprint

      # Add categories
      blueprint[:categories] = get_blueprint_categories(id)

      # Add enhanced NLP metadata if available
      if blueprint[:nlp_metadata]
        begin
          blueprint[:nlp_analysis] = JSON.parse(blueprint[:nlp_metadata])
        rescue JSON::ParserError
          # Ignore parsing errors for metadata
        end
      end

      blueprint
    end

    #
    # Lists all blueprints with pagination, ordered by creation date.
    #
    # Retrieves a collection of blueprints, with the most recently created ones
    # appearing first. Each blueprint in the returned array includes its
    # associated categories.
    #
    # @param limit [Integer] The maximum number of blueprints to return.
    # @param offset [Integer] The number of blueprints to skip, for pagination.
    #
    # @return [Array<Hash>] An array of blueprint hashes.
    #
    # @example
    #   # Get the 10 most recent blueprints
    #   recent_blueprints = db.list_blueprints(limit: 10)
    #
    #   # Get the next page of 10 blueprints
    #   next_page = db.list_blueprints(limit: 10, offset: 10)
    #
    def list_blueprints(limit: 100, offset: 0)
      blueprints = @db[:blueprints]
                   .order(Sequel.desc(:created_at))
                   .limit(limit)
                   .offset(offset)
                   .all

      # Add categories for each blueprint
      blueprints.each do |blueprint|
        blueprint[:categories] = get_blueprint_categories(blueprint[:id])
      end

      blueprints
    end

    #
    # Searches for blueprints by semantic similarity to a query string.
    #
    # This method generates a vector embedding for the `query` text and uses
    # `pgvector`'s cosine distance operator (`<->`) to find the most semantically
    # similar blueprints in the database. Results are ordered by similarity.
    #
    # @param query [String] The search query text.
    # @param limit [Integer] The maximum number of search results to return.
    #
    # @return [Array<Hash>] An array of blueprint hashes, sorted by relevance.
    #   Each hash includes a `:distance` key indicating similarity (lower is better).
    #   Returns an empty array if query embedding fails.
    #
    # @example
    #   results = db.search_blueprints(query: "http server in ruby", limit: 5)
    #   # => [{id: 12, ..., distance: 0.18}, {id: 34, ..., distance: 0.21}]
    #
    def search_blueprints(query:, limit: 10, enhanced: true)
      if enhanced
        # Use enhanced RAG service for hybrid search
        search_options = {
          max_results: limit,
          relevance_threshold: 0.3,
          include_patterns: true,
          boost_exact_matches: true
        }

        rag_search_result = @rag_service.search_blueprints(query, search_options)

        # Convert RAG results to database format
        blueprint_ids = rag_search_result[:results].map do |r|
          r[:blueprint_id] || r[:text_id]
        end.compact
        return [] if blueprint_ids.empty?

        # Fetch full blueprint data
        results = @db[:blueprints].where(id: blueprint_ids).all

        # Add categories and enhance with RAG analysis
        results.each do |blueprint|
          blueprint[:categories] = get_blueprint_categories(blueprint[:id])

          # Add RAG search metadata
          rag_match = rag_search_result[:results].find do |r|
            (r[:blueprint_id] || r[:text_id]) == blueprint[:id]
          end
          blueprint[:search_metadata] = rag_match if rag_match
          blueprint[:query_analysis] = rag_search_result[:query_analysis]
        end

        # Sort by RAG relevance score
        results.sort_by { |b| -(b.dig(:search_metadata, :final_score) || 0) }
      else
        # Fallback to traditional vector search
        traditional_vector_search(query, limit)
      end
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error in enhanced search: #{e.message}")
      # Fallback to traditional search on error
      traditional_vector_search(query, limit)
    end

    #
    # Deletes a blueprint and its category associations from the database.
    #
    # The deletion is performed in a transaction to ensure atomicity. It first
    # removes links in the `blueprints_categories` join table before deleting
    # the main blueprint record.
    #
    # @param id [Integer] The ID of the blueprint to delete.
    #
    # @return [Boolean] `true` if a record was successfully deleted, `false`
    #   otherwise (e.g., if the ID did not exist or an error occurred).
    #
    def delete_blueprint(id)
      @db.transaction do
        # Delete category associations
        @db[:blueprints_categories].where(blueprint_id: id).delete

        # Delete the blueprint
        deleted_count = @db[:blueprints].where(id: id).delete
        deleted_count > 0
      end
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error deleting blueprint: #{e.message}")
      false
    end

    #
    # Updates the attributes of an existing blueprint.
    #
    # This method updates a blueprint's data in a transaction. If `name` or
    # `description` are changed, the embedding vector is automatically
    # regenerated. If a `categories` array is provided, it will **replace**
    # all existing category associations for the blueprint.
    #
    # @param id [Integer] The ID of the blueprint to update.
    # @param code [String, nil] The new code content.
    # @param name [String, nil] The new name.
    # @param description [String, nil] The new description.
    # @param categories [Array<String>, nil] An array of category names to
    #   set for the blueprint, replacing any existing ones.
    #
    # @return [Hash, nil] The updated blueprint hash, or `nil` on failure.
    #
    def update_blueprint(id:, code: nil, name: nil, description: nil, categories: nil)
      updates = { updated_at: Time.now }
      updates[:code] = code if code
      updates[:name] = name if name
      updates[:description] = description if description

      # Regenerate embedding if name or description changed
      if name || description
        current = get_blueprint(id)
        new_name = name || current[:name]
        new_description = description || current[:description]
        content_to_embed = { name: new_name, description: new_description }.to_json
        begin
          embedding_result = RubyLLM.embed(content_to_embed)
          embedding_vector = embedding_result.vectors
          updates[:embedding] = Pgvector.encode(embedding_vector)
        rescue RubyLLM::Error => e
          BlueprintsCLI.logger.warn("Update embedding failed: #{e.message}")
          # Skip embedding update on failure
        rescue => e
          BlueprintsCLI.logger.warn("Update embedding generation failed: #{e.message}")
          # Skip embedding update on failure
        end
      end

      @db.transaction do
        # Update blueprint
        @db[:blueprints].where(id: id).update(updates)

        # Update categories if provided
        if categories
          @db[:blueprints_categories].where(blueprint_id: id).delete
          insert_blueprint_categories(id, categories)
        end

        # Return updated blueprint
        get_blueprint(id)
      end
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error updating blueprint: #{e.message}")
      nil
    end

    #
    # Retrieves all available categories from the database.
    #
    # @return [Array<Hash>] An array of hashes, where each hash represents a category.
    #
    def get_categories
      @db[:categories].all
    end

    #
    # Creates a new category or finds an existing one by title.
    #
    # If a category with the given title already exists, this method will not
    # create a duplicate. Instead, it will find and return the ID of the
    # existing category.
    #
    # @param title [String] The unique title for the category.
    # @param description [String, nil] An optional description for the category.
    #
    # @return [Integer] The ID of the created or existing category.
    #
    def create_category(title:, description: nil)
      @db[:categories].insert(
        title: title,
        created_at: Time.now,
        updated_at: Time.now
      )
    rescue Sequel::UniqueConstraintViolation
      # Category already exists, find and return it
      @db[:categories].where(title: title).first[:id]
    end

    #
    # Gathers basic statistics about the blueprints database.
    #
    # Provides a quick summary, including total counts of blueprints and
    # categories, and the database URL (with the password redacted).
    #
    # @return [Hash{Symbol => Object}] A hash with `:total_blueprints`,
    #   `:total_categories`, and `:database_url` keys.
    #
    def stats
      basic_stats = {
        total_blueprints: @db[:blueprints].count,
        total_categories: @db[:categories].count,
        database_url: @database_url.gsub(/:[^:@]*@/, ':***@') # Hide password
      }

      # Add enhanced RAG statistics
      rag_stats = @rag_service.get_statistics
      cache_stats = @cache_manager.statistics

      basic_stats.merge({
                          enhanced_features: {
                            rag_service: rag_stats,
                            cache_performance: cache_stats,
                            nlp_enabled: true,
                            search_index_size: rag_stats.dig(:search_index_stats) || {}
                          }
                        })
    rescue StandardError => e
      BlueprintsCLI.logger.warn("Error gathering enhanced stats: #{e.message}")
      basic_stats
    end

    # Find similar blueprints using enhanced RAG service
    def find_similar_blueprints(blueprint_id, options = {})
      @rag_service.find_similar_blueprints(blueprint_id, options)
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error finding similar blueprints: #{e.message}")
      []
    end

    # Analyze code patterns for a blueprint
    def analyze_blueprint_patterns(blueprint_id)
      blueprint = get_blueprint(blueprint_id)
      return {} unless blueprint

      @rag_service.analyze_code_patterns(blueprint)
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error analyzing blueprint patterns: #{e.message}")
      {}
    end

    # Rebuild the search index with all existing blueprints
    def rebuild_search_index
      blueprints = list_blueprints(limit: 10_000) # Get all blueprints
      @rag_service.rebuild_search_index(blueprints)
    rescue StandardError => e
      BlueprintsCLI.logger.warn("Error rebuilding search index: #{e.message}")
    end

    # Get enhanced search suggestions based on query
    def get_search_suggestions(partial_query, limit: 5)
      # Use Trie-based prefix search from RAG service
      suggestions = []

      # Get recent searches from cache
      if @rag_service.search_index && @rag_service.search_index[:trie]
        trie = @rag_service.search_index[:trie]
        matches = trie.wildcard("#{partial_query.downcase}*")
        suggestions = matches.first(limit)
      end

      suggestions
    rescue StandardError => e
      BlueprintsCLI.logger.warn("Error getting search suggestions: #{e.message}")
      []
    end

    # Get blueprint recommendations based on user patterns
    def get_recommendations(user_context = {}, limit: 5)
      # Use priority queue from RAG service to get top-ranked blueprints
      if @rag_service.search_index && @rag_service.search_index[:priority_rankings]
        recommendations = []
        temp_queue = @rag_service.search_index[:priority_rankings].dup

        count = 0
        while !temp_queue.empty? && count < limit
          ranked_item = temp_queue.pop
          blueprint_id = ranked_item[:blueprint_id] || ranked_item[:text_id]
          blueprint = get_blueprint(blueprint_id) if blueprint_id
          recommendations << blueprint if blueprint
          count += 1
        end

        recommendations
      else
        # Fallback to recent blueprints
        list_blueprints(limit: limit)
      end
    rescue StandardError => e
      BlueprintsCLI.logger.warn("Error getting recommendations: #{e.message}")
      list_blueprints(limit: limit)
    end

    private

    #
    # Loads the database URL from the unified configuration system.
    #
    # @!visibility private
    # @return [String] The database connection URL.
    #
    def load_database_url
      BlueprintsCLI.configuration.database_url
    end

    #
    # Establishes a connection to the database using Sequel.
    #
    # @!visibility private
    # @return [Sequel::Database] The database connection object.
    # @raise [StandardError] If the connection fails.
    #
    def connect_to_database
      Sequel.connect(@database_url)
    rescue StandardError => e
      BlueprintsCLI.logger.fatal("Failed to connect to database: #{e.message}")
      puts "Database URL: #{@database_url.gsub(/:[^:@]*@/, ':***@')}".colorize(:yellow)
      raise e
    end

    #
    # Validates that the required database tables and extensions exist.
    #
    # @!visibility private
    # @raise [StandardError] If a required table is not found.
    #
    def validate_database_schema
      required_tables = %i[blueprints categories blueprints_categories]

      required_tables.each do |table|
        raise "Missing required table: #{table}. Please ensure the blueprints database is properly set up." unless @db.table_exists?(table)
      end

      # Check for vector extension
      return if @db.fetch("SELECT 1 FROM pg_extension WHERE extname = 'vector'").first

      BlueprintsCLI.logger.warn('pgvector extension not found. Vector search may not work.')
    end

    #
    # Fetches all categories associated with a given blueprint ID.
    #
    # @!visibility private
    # @param blueprint_id [Integer] The blueprint's ID.
    # @return [Array<Hash>] An array of category hashes.
    #
    def get_blueprint_categories(blueprint_id)
      @db.fetch(
        "SELECT c.* FROM categories c
           JOIN blueprints_categories bc ON c.id = bc.category_id
           WHERE bc.blueprint_id = ?",
        blueprint_id
      ).all
    end

    #
    # Associates a list of categories with a blueprint.
    #
    # For each category name, it finds or creates the category record and then
    # creates a link in the `blueprints_categories` join table.
    #
    # @!visibility private
    # @param blueprint_id [Integer] The ID of the blueprint to link.
    # @param category_names [Array<String>] The names of the categories to link.
    #
    def insert_blueprint_categories(blueprint_id, category_names)
      category_names.each do |category_name|
        category_name = category_name.strip
        next if category_name.empty?

        # Find or create category
        category = @db[:categories].where(title: category_name).first
        category_id = if category
                        category[:id]
                      else
                        create_category(title: category_name)
                      end

        # Link blueprint to category
        @db[:blueprints_categories].insert_ignore.insert(
          blueprint_id: blueprint_id,
          category_id: category_id
        )
      end
    end

    # Traditional vector search fallback
    def traditional_vector_search(query, limit)
      # Generate embedding for the search query
      begin
        query_embedding_result = RubyLLM.embed(query)
        query_embedding_vector = query_embedding_result.vectors
      rescue RubyLLM::Error => e
        BlueprintsCLI.logger.warn("Search embedding failed: #{e.message}")
        return []
      rescue => e
        BlueprintsCLI.logger.warn("Search embedding generation failed: #{e.message}")
        return []
      end

      return [] unless query_embedding_vector&.any?
      query_embedding = Pgvector.encode(query_embedding_vector)

      # Perform vector similarity search using pgvector
      results = @db.fetch(
        "SELECT *, embedding <-> ? AS distance
           FROM blueprints
           ORDER BY embedding <-> ?
           LIMIT ?",
        query_embedding, query_embedding, limit
      ).all

      # Add categories for each result
      results.each do |blueprint|
        blueprint[:categories] = get_blueprint_categories(blueprint[:id])
      end

      results
    end

    # Generate fallback embedding using RubyLLM
    def generate_fallback_embedding(blueprint_data)
      content_to_embed = {
        name: blueprint_data[:name],
        description: blueprint_data[:description]
      }.to_json

      embedding_result = RubyLLM.embed(content_to_embed)
      embedding_result.vectors
    rescue RubyLLM::Error => e
      BlueprintsCLI.logger.warn("RubyLLM fallback embedding failed: #{e.message}")
      # Return zero vector as last resort
      Array.new(768, 0.0)
    rescue StandardError => e
      BlueprintsCLI.logger.warn("Error generating fallback embedding: #{e.message}")
      # Return zero vector as last resort
      Array.new(768, 0.0)
    end
  end
end
