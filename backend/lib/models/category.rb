# frozen_string_literal: true

require 'sequel'

module BlueprintsCLI
  module Models
    ##
    # Category model for organizing blueprints
    #
    # @attr [Integer] id Unique identifier
    # @attr [String] name Category name
    # @attr [String] description Category description
    # @attr [Time] created_at Creation timestamp
    # @attr [Time] updated_at Last update timestamp
    #
    class Category < Sequel::Model
      # Enable timestamps
      plugin :timestamps, update_on_create: true

      # Enable validation
      plugin :validation_helpers

      # Enable JSON serialization
      plugin :json_serializer

      # Many-to-many relationship with blueprints
      many_to_many :blueprints,
                   left_key: :category_id,
                   right_key: :blueprint_id,
                   join_table: :blueprint_categories

      # Validations
      def validate
        super
        validates_presence [:name]
        validates_unique :name
        validates_max_length 100, :name
        validates_max_length 500, :description, allow_nil: true
        validates_format(/\A[a-z0-9_-]+\z/, :name,
                         message: 'must contain only lowercase letters, numbers, underscores, and dashes')
      end

      # Hooks
      def before_create
        super
        self.name = name.downcase.strip if name
        self.created_at = Time.now
        self.updated_at = Time.now
      end

      def before_update
        super
        self.name = name.downcase.strip if name
        self.updated_at = Time.now
      end

      # Instance methods

      ##
      # Convert to hash for JSON serialization
      # @return [Hash] Category data as hash
      def to_hash
        {
          id: id,
          name: name,
          description: description,
          blueprint_count: blueprints_dataset.count,
          created_at: created_at&.iso8601,
          updated_at: updated_at&.iso8601
        }
      end

      ##
      # Get blueprint count for this category
      # @return [Integer] Number of blueprints
      def blueprint_count
        blueprints_dataset.count
      end

      # Class methods

      ##
      # Find or create category by name
      # @param name [String] Category name
      # @param description [String, nil] Optional description
      # @return [Category] Found or created category
      def self.find_or_create_by_name(name, description: nil)
        normalized_name = name.downcase.strip

        existing = first(name: normalized_name)
        return existing if existing

        create(
          name: normalized_name,
          description: description
        )
      end

      ##
      # Get categories with blueprint counts
      # @param min_count [Integer] Minimum blueprint count
      # @return [Array<Category>] Categories with counts
      def self.with_blueprint_counts(min_count: 0)
        join(:blueprint_categories, category_id: :id)
          .group(:categories__id)
          .having { count(:blueprint_categories__blueprint_id) >= min_count }
          .select_append { count(:blueprint_categories__blueprint_id).as(:blueprint_count) }
          .order(Sequel.desc(:blueprint_count))
          .all
      end

      ##
      # Get popular categories (by blueprint count)
      # @param limit [Integer] Maximum results
      # @return [Array<Category>] Popular categories
      def self.popular(limit: 10)
        with_blueprint_counts
          .limit(limit)
      end

      ##
      # Search categories by name or description
      # @param query [String] Search query
      # @return [Array<Category>] Matching categories
      def self.search(query)
        return all if query.nil? || query.empty?

        search_condition = Sequel.ilike(:name, "%#{query}%") |
                           Sequel.ilike(:description, "%#{query}%")

        where(search_condition)
          .order(:name)
          .all
      end

      ##
      # Get all categories ordered by name
      # @return [Array<Category>] All categories
      def self.ordered
        order(:name).all
      end

      ##
      # Batch create categories from names array
      # @param names [Array<String>] Category names
      # @return [Array<Category>] Created categories
      def self.create_from_names(names)
        names.map do |name|
          find_or_create_by_name(name)
        end.compact
      end
    end
  end
end
