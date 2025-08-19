# frozen_string_literal: true

require_relative '../models/blueprint'
require_relative '../models/category'
require 'dry-monads'

module BlueprintsCLI
  module Services
    ##
    # Service class for managing blueprint operations
    # Provides high-level business logic for blueprint CRUD operations
    #
    class BlueprintService
      include Dry::Monads[:result, :try]

      ##
      # Initialize service with optional logger
      # @param logger [Logger] Optional logger instance
      def initialize(logger: LOGGER)
        @logger = logger
      end

      ##
      # List blueprints with optional filtering and pagination
      # @param params [Hash] Query parameters
      # @option params [String] :search Search query
      # @option params [String] :language Filter by language
      # @option params [String] :framework Filter by framework
      # @option params [Array<String>] :categories Filter by categories
      # @option params [Integer] :limit Results limit (default: 20)
      # @option params [Integer] :offset Results offset (default: 0)
      # @option params [String] :sort Sort field (default: 'created_at')
      # @option params [String] :order Sort order 'asc' or 'desc' (default: 'desc')
      # @return [Hash] Blueprints with pagination metadata
      def list(params = {})
        Try do
          @logger.info "Listing blueprints with params: #{params}"

          result = Models::Blueprint.search(params[:search], params)

          @logger.info "Found #{result[:pagination][:total]} blueprints"
          result
        end.to_result.or do |error|
          @logger.error "Failed to list blueprints: #{error.message}"
          handle_error(error)
        end
      end

      ##
      # Create a new blueprint
      # @param data [Hash] Blueprint data
      # @option data [String] :name Blueprint name (required)
      # @option data [String] :description Blueprint description (required)
      # @option data [String] :code Blueprint code (required)
      # @option data [String] :language Programming language
      # @option data [String] :framework Framework
      # @option data [String] :type Blueprint type
      # @option data [Array<String>] :categories Category names
      # @return [Result] Success with blueprint or failure with error
      def create(data)
        Try do
          DB.transaction do
            @logger.info "Creating blueprint: #{data[:name]}"

            # Validate required fields
            validate_required_fields!(data, %i[name description code])

            # Create blueprint
            blueprint_data = extract_blueprint_data(data)
            blueprint = Models::Blueprint.create(blueprint_data)

            # Associate categories if provided
            if data[:categories] && data[:categories].any?
              categories = Models::Category.create_from_names(data[:categories])
              blueprint.add_categories(categories)
            end

            @logger.info "Created blueprint #{blueprint.id}: #{blueprint.name}"
            blueprint
          end
        end.to_result.or do |error|
          @logger.error "Failed to create blueprint: #{error.message}"
          handle_error(error)
        end
      end

      ##
      # Find blueprint by ID
      # @param id [Integer, String] Blueprint ID
      # @return [Models::Blueprint, nil] Blueprint or nil if not found
      def find(id)
        Try do
          @logger.info "Finding blueprint: #{id}"
          blueprint = Models::Blueprint[id.to_i]

          if blueprint
            @logger.info "Found blueprint: #{blueprint.name}"
          else
            @logger.warn "Blueprint not found: #{id}"
          end

          blueprint
        end.to_result.or do |error|
          @logger.error "Failed to find blueprint #{id}: #{error.message}"
          nil
        end
      end

      ##
      # Update blueprint by ID
      # @param id [Integer, String] Blueprint ID
      # @param data [Hash] Update data
      # @return [Result] Success with blueprint or failure with error
      def update(id, data)
        Try do
          DB.transaction do
            @logger.info "Updating blueprint: #{id}"

            blueprint = Models::Blueprint[id.to_i]
            return nil unless blueprint

            # Extract and validate update data
            update_data = extract_blueprint_data(data)
            blueprint.update(update_data)

            # Update categories if provided
            if data[:categories]
              blueprint.remove_all_categories
              if data[:categories].any?
                categories = Models::Category.create_from_names(data[:categories])
                blueprint.add_categories(categories)
              end
            end

            @logger.info "Updated blueprint #{blueprint.id}: #{blueprint.name}"
            blueprint
          end
        end.to_result.or do |error|
          @logger.error "Failed to update blueprint #{id}: #{error.message}"
          handle_error(error)
        end
      end

      ##
      # Delete blueprint by ID
      # @param id [Integer, String] Blueprint ID
      # @return [Boolean] Success status
      def delete(id)
        Try do
          DB.transaction do
            @logger.info "Deleting blueprint: #{id}"

            blueprint = Models::Blueprint[id.to_i]
            return false unless blueprint

            # Remove category associations
            blueprint.remove_all_categories

            # Delete blueprint
            blueprint.delete

            @logger.info "Deleted blueprint: #{id}"
            true
          end
        end.to_result.or do |error|
          @logger.error "Failed to delete blueprint #{id}: #{error.message}"
          false
        end
      end

      ##
      # Search blueprints with advanced options
      # @param query [String] Search query
      # @param options [Hash] Search options
      # @return [Hash] Search results with metadata
      def search(query, options = {})
        Try do
          @logger.info "Searching blueprints: '#{query}' with options: #{options}"

          result = Models::Blueprint.search(query, options)

          # Add facets for advanced filtering
          result[:facets] = build_search_facets(query, options)

          @logger.info "Search returned #{result[:pagination][:total]} results"
          result
        end.to_result.or do |error|
          @logger.error "Search failed: #{error.message}"
          handle_error(error)
        end
      end

      ##
      # Find related blueprints by similarity
      # @param blueprint_id [Integer] Blueprint ID
      # @param limit [Integer] Maximum results
      # @return [Array<Models::Blueprint>] Related blueprints
      def find_related(blueprint_id, limit: 5)
        Try do
          @logger.info "Finding related blueprints for: #{blueprint_id}"

          blueprint = Models::Blueprint[blueprint_id]
          return [] unless blueprint

          related = blueprint.similar(limit: limit)

          @logger.info "Found #{related.length} related blueprints"
          related.map(&:to_hash)
        end.to_result.or do |error|
          @logger.error "Failed to find related blueprints: #{error.message}"
          []
        end
      end

      ##
      # Get blueprints by category
      # @param category_name [String] Category name
      # @param limit [Integer] Maximum results
      # @return [Array<Hash>] Blueprint data
      def by_category(category_name, limit: 20)
        Try do
          @logger.info "Getting blueprints for category: #{category_name}"

          blueprints = Models::Blueprint.by_category(category_name, limit: limit)
          result = blueprints.map(&:to_hash)

          @logger.info "Found #{result.length} blueprints in category"
          result
        end.to_result.or do |error|
          @logger.error "Failed to get blueprints by category: #{error.message}"
          []
        end
      end

      private

      ##
      # Extract blueprint data from input hash
      # @param data [Hash] Input data
      # @return [Hash] Cleaned blueprint data
      def extract_blueprint_data(data)
        {
          name: data[:name]&.strip,
          description: data[:description]&.strip,
          code: data[:code],
          language: data[:language] || 'javascript',
          framework: data[:framework],
          type: data[:type]
        }.compact
      end

      ##
      # Validate required fields are present
      # @param data [Hash] Input data
      # @param required_fields [Array<Symbol>] Required field names
      # @raise [ArgumentError] If required fields are missing
      def validate_required_fields!(data, required_fields)
        missing_fields = required_fields.select do |field|
          data[field].nil? || data[field].to_s.strip.empty?
        end

        return unless missing_fields.any?

        raise ArgumentError, "Missing required fields: #{missing_fields.join(', ')}"
      end

      ##
      # Build search facets for filtering
      # @param query [String] Search query
      # @param options [Hash] Search options
      # @return [Hash] Facet data
      def build_search_facets(query, options)
        {
          languages: get_facet_counts(:language, query, options),
          frameworks: get_facet_counts(:framework, query, options),
          types: get_facet_counts(:type, query, options)
        }
      end

      ##
      # Get facet counts for a field
      # @param field [Symbol] Field name
      # @param query [String] Search query
      # @param options [Hash] Search options
      # @return [Array<Hash>] Facet counts
      def get_facet_counts(field, _query, _options)
        Models::Blueprint
          .group_and_count(field)
          .where(field => nil..) # Exclude nulls
          .order(Sequel.desc(:count))
          .limit(10)
          .all
          .map { |row| { name: row[field], count: row[:count] } }
      end

      ##
      # Handle service errors
      # @param error [Exception] The error
      # @return [Hash] Error response
      def handle_error(error)
        {
          error: error.message,
          type: error.class.name
        }
      end
    end
  end
end
