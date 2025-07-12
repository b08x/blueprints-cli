# frozen_string_literal: true

require_relative 'db/interface'

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

    # The Google Gemini model used for generating text embeddings.
    EMBEDDING_MODEL = 'text-embedding-004'
    # The number of dimensions for the text embedding vectors.
    EMBEDDING_DIMENSIONS = 768

    # @!attribute [r] db
    #   @return [Sequel::Database] The active Sequel database connection instance.
    attr_reader :db

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
    def initialize(database_url: nil)
      @database_url = database_url || load_database_url
      @db = connect_to_database
      @gemini_api_key = load_gemini_api_key

      validate_database_schema
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
    def create_blueprint(code:, name: nil, description: nil, categories: [])
      @db.transaction do
        # Insert blueprint record
        blueprint_id = @db[:blueprints].insert(
          code: code,
          name: name,
          description: description,
          embedding: generate_embedding(name: name, description: description),
          created_at: Time.now,
          updated_at: Time.now
        )

        # Handle categories if provided
        insert_blueprint_categories(blueprint_id, categories) if categories.any?

        # Return the created blueprint
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
    def search_blueprints(query:, limit: 10)
      # Generate embedding for the search query
      query_embedding = generate_embedding_for_text(query)
      return [] unless query_embedding

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
        updates[:embedding] = generate_embedding(name: new_name, description: new_description)
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
      {
        total_blueprints: @db[:blueprints].count,
        total_categories: @db[:categories].count,
        database_url: @database_url.gsub(/:[^:@]*@/, ':***@') # Hide password
      }
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
    # Loads the Gemini API key from the unified configuration system.
    #
    # @!visibility private
    # @return [String, nil] The API key.
    #
    def load_gemini_api_key
      BlueprintsCLI.configuration.ai_api_key('gemini')
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
    # Generates an embedding vector for a name and description combination.
    #
    # @!visibility private
    # @param name [String] The name of the blueprint.
    # @param description [String] The description of the blueprint.
    # @return [String, nil] A string representation of the vector `"[d1,d2,...]"`.
    #
    def generate_embedding(name:, description:)
      content = { name: name, description: description }.to_json
      generate_embedding_for_text(content)
    end

    #
    # Generates an embedding vector for arbitrary text using the Google Gemini API.
    #
    # @!visibility private
    # @param text [String] The text to embed.
    # @return [String, nil] A string representation of the vector `"[d1,d2,...]"`,
    #   or `nil` if the API call fails or a key is missing.
    #
    def generate_embedding_for_text(text)
      unless @gemini_api_key
        BlueprintsCLI.logger.warn('No Gemini API key found. Skipping embedding generation.')
        return nil
      end

      uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{EMBEDDING_MODEL}:embedContent")
      uri.query = URI.encode_www_form(key: @gemini_api_key)

      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = {
        model: "models/#{EMBEDDING_MODEL}",
        content: {
          parts: [{ text: text }]
        }
      }.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code == '200'
        data = JSON.parse(response.body)
        embedding = data.dig('embedding', 'values')

        if embedding && embedding.length == EMBEDDING_DIMENSIONS
          "[#{embedding.join(',')}]" # Format as PostgreSQL vector
        else
          puts '⚠️  Warning: Invalid embedding dimensions received'.colorize(:yellow)
          nil
        end
      else
        BlueprintsCLI.logger.failure("Error generating embedding: #{response.code} #{response.message}")
        BlueprintsCLI.logger.debug(response.body) if ENV['DEBUG']
        nil
      end
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error calling Gemini API: #{e.message}")
      nil
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
  end
end
