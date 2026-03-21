# frozen_string_literal: true

require "json"
require "dry/monads"
require_relative "db/interface"

module BlueprintsCLI
  # Provides a direct database interface for managing "blueprints" (code snippets).
  #
  # This class encapsulates all database operations for blueprints, including
  # standard CRUD actions, category management, and advanced vector-based
  # similarity searches. It uses the Sequel ORM to interact with a PostgreSQL
  # database (requiring the `pgvector` extension for search) and leverages the
  # Ollama API to generate text embeddings for semantic search capabilities.
  #
  # Configuration is loaded from the unified configuration system via
  # `BlueprintsCLI::Configuration`, environment variables, or sensible defaults.
  #
  class BlueprintDatabase
    include BlueprintsCLI::Interfaces::DatabaseInterface
    include Dry::Monads[:result, :do]

    # The Ollama embedding model used for generating text embeddings.
    EMBEDDING_MODEL = "embeddinggemma:latest"
    # The number of dimensions for the text embedding vectors.
    EMBEDDING_DIMENSIONS = 768

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
    # @return [Dry::Monads::Result] Success(blueprint_hash) or Failure(reason)
    #
    def create_blueprint(code:, name: nil, description: nil, categories: [])
      # Try to generate embedding, but allow NULL if Ollama is unavailable
      embedding_result = generate_embedding(name:, description:)

      embedding = case embedding_result
                  when Success then embedding_result.value!
                  when Failure
                    return embedding_result unless embedding_result.failure == :ollama_unavailable

                    BlueprintsCLI.logger.debug("Creating blueprint with NULL embedding - will be processed later")
                    nil # Allow NULL embedding

        # For other embedding errors, still fail the creation

      end

      blueprint_id = nil
      @db.transaction do
        # Insert blueprint record
        blueprint_id = @db[:blueprints].insert(
          code:,
          name:,
          description:,
          embedding:,
          created_at: Time.now,
          updated_at: Time.now
        )

        # Store in cache for future access (disabled for now)
        # @cache_manager.store(:pipeline, blueprint_data.to_json, @rag_service.config, rag_result)

        # Handle categories if provided
        insert_blueprint_categories(blueprint_id, categories) if categories.any?
      end

      # Return the created blueprint wrapped in Success
      result = get_blueprint(blueprint_id)

      # If embedding is missing due to Ollama unavailability, return failure to signal this
      # but the blueprint has been successfully saved
      return Failure(:ollama_unavailable) if embedding.nil?

      Success(result)
    rescue Sequel::Error => e
      BlueprintsCLI.logger.failure("Database error creating blueprint: #{e.message}")
      Failure(e)
    rescue => e
      BlueprintsCLI.logger.failure("Error creating blueprint: #{e.message}")
      Failure(e)
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
      blueprint = @db[:blueprints].where(id:).first
      return nil unless blueprint

      # Add categories
      blueprint[:categories] = get_blueprint_categories(id)

      # Enhanced NLP metadata is disabled - skip parsing

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
    def search_blueprints(query:, limit: 10, enhanced: false)
      # Enhanced RAG search is temporarily disabled, use traditional vector search
      traditional_vector_search(query, limit)
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error in search: #{e.message}")
      # Return empty array if search fails completely
      []
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
        deleted_count = @db[:blueprints].where(id:).delete
        deleted_count.positive?
      end
    rescue => e
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
        rescue StandardError => e
          BlueprintsCLI.logger.warn("Update embedding generation failed: #{e.message}")
          # Skip embedding update on failure
        end
      end

      @db.transaction do
        # Update blueprint
        @db[:blueprints].where(id:).update(updates)

        # Update categories if provided
        if categories
          @db[:blueprints_categories].where(blueprint_id: id).delete
          insert_blueprint_categories(id, categories)
        end

        # Return updated blueprint
        get_blueprint(id)
      end
    rescue => e
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
        title:,
        created_at: Time.now,
        updated_at: Time.now
      )
    rescue Sequel::UniqueConstraintViolation
      # Category already exists, find and return it
      @db[:categories].where(title:).first[:id]
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
      {
        total_blueprints: @db[:blueprints].count,
        total_categories: @db[:categories].count,
        database_url: @database_url.gsub(/:[^:@]*@/, ":***@"), # Hide password
      }
    end

    # Check if Ollama service is available for embedding generation
    #
    # @return [Boolean] true if Ollama is accessible, false otherwise
    def ollama_available?
      ollama_base = BlueprintsCLI.configuration.fetch(:ai, :rubyllm, :ollama_api_base, default: "http://localhost:11434")

      # Quick health check by attempting to reach Ollama's tags endpoint
      require "net/http"
      require "timeout"

      uri = URI.join(ollama_base, "/api/tags")

      Timeout.timeout(5) do
        response = Net::HTTP.get_response(uri)
        response.code == "200"
      end

      true
    rescue => e
      BlueprintsCLI.logger.debug("Ollama health check failed: #{e.message}")
      false
    end

    private def load_database_url
      BlueprintsCLI.configuration.database_url
    end

    #
    # Loads the Gemini API key from the unified configuration system.
    #
    # @!visibility private
    # @return [String, nil] The API key.
    #
    private def load_gemini_api_key
      BlueprintsCLI.configuration.ai_api_key("gemini")
    end

    #
    # Establishes a connection to the database using Sequel.
    #
    # @!visibility private
    # @return [Sequel::Database] The database connection object.
    # @raise [StandardError] If the connection fails.
    #
    private def connect_to_database
      Sequel.connect(@database_url)
    rescue => e
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
    private def validate_database_schema
      required_tables = %i[blueprints categories blueprints_categories]

      required_tables.each do |table|
        unless @db.table_exists?(table)
          raise "Missing required table: #{table}. Please ensure the blueprints database is properly set up."
        end
      end

      # Check for vector extension
      return if @db.fetch("SELECT 1 FROM pg_extension WHERE extname = 'vector'").first

      BlueprintsCLI.logger.warn("pgvector extension not found. Vector search may not work.")
    end

    #
    # Generates an embedding vector for a name and description combination.
    #
    # @!visibility private
    # @param name [String] The name of the blueprint.
    # @param description [String] The description of the blueprint.
    # @return [String, nil] A string representation of the vector `"[d1,d2,...]"`.
    #
    private def generate_embedding(name:, description:)
      content = { name:, description: }.to_json
      generate_embedding_for_text(content)
    end

    # Process blueprints with missing embeddings
    #
    # Finds all blueprints that have NULL embeddings and attempts to generate
    # embeddings for them using the current Ollama configuration.
    #
    # @param batch_size [Integer] Number of blueprints to process in each batch
    # @return [Hash] Summary of processed blueprints
    private def generate_missing_embeddings(batch_size: 10)
      processed = 0
      failed = 0
      skipped = 0

      # Find blueprints without embeddings
      blueprints_without_embeddings = @db[:blueprints]
        .where(embedding: nil)
        .limit(batch_size)

      BlueprintsCLI.logger.info("Found #{blueprints_without_embeddings.count} blueprints needing embeddings")

      blueprints_without_embeddings.each do |blueprint|
        # Generate embedding
        embedding_result = generate_embedding(
          name: blueprint[:name],
          description: blueprint[:description]
        )

        if embedding_result.success?
          # Update the blueprint with the new embedding
          @db[:blueprints]
            .where(id: blueprint[:id])
            .update(embedding: embedding_result.value!)

          processed += 1
          BlueprintsCLI.logger.debug("Generated embedding for blueprint #{blueprint[:id]}: #{blueprint[:name]}")
        elsif embedding_result.failure == :ollama_unavailable
          BlueprintsCLI.logger.warning("Ollama unavailable, stopping batch processing")
          skipped += 1
          break
        else
          BlueprintsCLI.logger.error("Failed to generate embedding for blueprint #{blueprint[:id]}: #{embedding_result.failure}")
          failed += 1
        end
      rescue => e
        BlueprintsCLI.logger.error("Error processing blueprint #{blueprint[:id]}: #{e.message}")
        failed += 1
      end

      summary = {
        processed:,
        failed:,
        skipped:,
        total_found: blueprints_without_embeddings.count,
      }

      BlueprintsCLI.logger.info("Embedding generation complete: #{processed} processed, #{failed} failed, #{skipped} skipped")
      summary
    end

    #
    # Generates an embedding vector for arbitrary text using the unified RubyLLM API.
    #
    # @!visibility private
    # @param text [String] The text to embed.
    # @return [Dry::Monads::Result] Success(vector_string) or Failure(reason)
    #
    private def generate_embedding_for_text(text)
      # Ensure RubyLLM is configured
      BlueprintsCLI.configuration.configure_rubyllm!

      # Validate Ollama connectivity before attempting embedding generation
      unless ollama_available?
        BlueprintsCLI.logger.warning("Ollama service unavailable - blueprint will be queued for embedding when service returns")
        return Failure(:ollama_unavailable)
      end

      embedding = RubyLLM.embed(text)
      vector = embedding.vectors

      if vector && !vector.empty?
        Success("[#{vector.join(',')}]") # Format as PostgreSQL vector
      else
        BlueprintsCLI.logger.failure("Invalid embedding dimensions received")
        Failure(:invalid_embedding)
      end
    rescue RubyLLM::Error => e
      # Check if this is an Ollama connectivity issue
      if e.message.match?(/connection|refused|timeout|unreachable/i)
        BlueprintsCLI.logger.warning("Ollama connection error - blueprint will be queued for embedding: #{e.message}")
        return Failure(:ollama_unavailable)
      end
      BlueprintsCLI.logger.failure("Error generating embedding: #{e.message}")
      Failure(e)
    rescue => e
      BlueprintsCLI.logger.failure("Unexpected error in embedding generation: #{e.message}")
      Failure(e)
    end

    #
    # Fetches all categories associated with a given blueprint ID.
    #
    # @!visibility private
    # @param blueprint_id [Integer] The blueprint's ID.
    # @return [Array<Hash>] An array of category hashes.
    #
    private def get_blueprint_categories(blueprint_id)
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
    private def insert_blueprint_categories(blueprint_id, category_names)
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
          blueprint_id:,
          category_id:
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
      rescue StandardError => e
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
