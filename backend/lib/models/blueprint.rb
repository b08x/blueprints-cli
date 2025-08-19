# frozen_string_literal: true

require 'sequel'

module BlueprintsCLI
  module Models
    ##
    # Blueprint model represents a code blueprint with metadata
    #
    # @attr [Integer] id Unique identifier
    # @attr [String] name Blueprint name
    # @attr [String] description Blueprint description
    # @attr [String] code The actual code content
    # @attr [String] language Programming language (default: 'javascript')
    # @attr [String] framework Framework or library used
    # @attr [String] type Type of blueprint (component, utility, etc.)
    # @attr [Time] created_at Creation timestamp
    # @attr [Time] updated_at Last update timestamp
    # @attr [Sequel::Postgres::PGArray] embedding Vector embedding for similarity search
    #
    class Blueprint < Sequel::Model
      # Enable timestamps
      plugin :timestamps, update_on_create: true

      # Enable validation
      plugin :validation_helpers

      # Enable JSON serialization
      plugin :json_serializer

      # Many-to-many relationship with categories
      many_to_many :categories,
                   left_key: :blueprint_id,
                   right_key: :category_id,
                   join_table: :blueprint_categories

      # Validations
      def validate
        super
        validates_presence %i[name description code]
        validates_unique :name
        validates_max_length 255, :name
        validates_max_length 1000, :description
        validates_includes %w[javascript python ruby java csharp go rust typescript],
                           :language, allow_nil: true
      end

      # Hooks
      def before_create
        super
        self.language ||= 'javascript'
        self.created_at = Time.now
        self.updated_at = Time.now
      end

      def before_update
        super
        self.updated_at = Time.now
      end

      # Instance methods

      ##
      # Convert to hash for JSON serialization
      # @return [Hash] Blueprint data as hash
      def to_hash
        {
          id: id,
          name: name,
          description: description,
          code: code,
          language: language,
          framework: framework,
          type: type,
          created_at: created_at&.iso8601,
          updated_at: updated_at&.iso8601
        }
      end

      ##
      # Get similar blueprints using vector similarity
      # @param limit [Integer] Maximum number of results
      # @return [Array<Blueprint>] Similar blueprints
      def similar(limit: 5)
        return [] unless embedding

        self.class.exclude(id: id)
            .where(Sequel.lit('embedding <-> ? < 0.8', Sequel.pg_array(embedding)))
            .order(Sequel.lit('embedding <-> ?', Sequel.pg_array(embedding)))
            .limit(limit)
            .all
      end

      ##
      # Update embedding vector
      # @param vector [Array<Float>] Embedding vector
      def update_embedding(vector)
        update(embedding: Sequel.pg_array(vector))
      end

      # Class methods

      ##
      # Search blueprints by text query
      # @param query [String] Search query
      # @param options [Hash] Search options
      # @option options [Integer] :limit Maximum results (default: 20)
      # @option options [Integer] :offset Results offset (default: 0)
      # @option options [String] :language Filter by language
      # @option options [String] :framework Filter by framework
      # @option options [Array<String>] :categories Filter by category names
      # @return [Hash] Search results with pagination info
      def self.search(query = nil, options = {})
        dataset = self

        # Apply text search if query provided
        if query && !query.empty?
          search_condition = Sequel.ilike(:name, "%#{query}%") |
                             Sequel.ilike(:description, "%#{query}%") |
                             Sequel.ilike(:code, "%#{query}%")
          dataset = dataset.where(search_condition)
        end

        # Apply filters
        dataset = dataset.where(language: options[:language]) if options[:language]
        dataset = dataset.where(framework: options[:framework]) if options[:framework]

        # Filter by categories if specified
        if options[:categories] && !options[:categories].empty?
          dataset = dataset.join(:blueprint_categories, blueprint_id: :id)
                           .join(:categories, id: :category_id)
                           .where(categories__name: options[:categories])
                           .distinct
        end

        # Get total count before pagination
        total = dataset.count

        # Apply pagination
        limit = [options[:limit] || 20, 100].min
        offset = options[:offset] || 0

        results = dataset.limit(limit, offset)
                         .order(Sequel.desc(:updated_at))
                         .all

        {
          blueprints: results.map(&:to_hash),
          pagination: {
            total: total,
            limit: limit,
            offset: offset,
            has_more: (offset + limit) < total
          }
        }
      end

      ##
      # Find blueprints by category
      # @param category_name [String] Category name
      # @param limit [Integer] Maximum results
      # @return [Array<Blueprint>] Blueprints in category
      def self.by_category(category_name, limit: 20)
        join(:blueprint_categories, blueprint_id: :id)
          .join(:categories, id: :category_id)
          .where(categories__name: category_name)
          .limit(limit)
          .order(Sequel.desc(:updated_at))
          .all
      end

      ##
      # Get recent blueprints
      # @param limit [Integer] Maximum results
      # @return [Array<Blueprint>] Recent blueprints
      def self.recent(limit: 10)
        order(Sequel.desc(:created_at))
          .limit(limit)
          .all
      end

      ##
      # Get popular blueprints (placeholder for future analytics)
      # @param limit [Integer] Maximum results
      # @return [Array<Blueprint>] Popular blueprints
      def self.popular(limit: 10)
        # For now, return recent blueprints
        # TODO: Implement view/usage tracking
        recent(limit: limit)
      end
    end
  end
end
