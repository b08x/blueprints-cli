# frozen_string_literal: true

module BlueprintsCLI
  module Actions
    ##
    # Submit handles the submission of blueprints to the database.
    # It provides functionality to generate missing metadata, validate the blueprint data,
    # and store the blueprint in the database. This class is useful for automating the
    # process of submitting blueprints with minimal initial information, as it can
    # auto-generate names, descriptions, and categories.
    #
    # @example Basic usage:
    #   action = Submit.new(code: "puts 'Hello, World!'")
    #   action.call
    class Submit < Sublayer::Actions::Base
      ##
      # Initializes a new Submit with the provided code and optional metadata.
      #
      # @param code [String] The code content of the blueprint. This is the only required parameter.
      # @param name [String, nil] The name of the blueprint. If not provided, it will be auto-generated.
      # @param description [String, nil] The description of the blueprint. If not provided and auto_describe is true, it will be auto-generated.
      # @param categories [Array, nil] The categories of the blueprint. If not provided and auto_categorize is true, they will be auto-generated.
      # @param filename [String, nil] The original filename for type detection.
      # @param auto_describe [Boolean] Whether to auto-generate the description if not provided. Defaults to true.
      # @param auto_categorize [Boolean] Whether to auto-generate the categories if not provided. Defaults to true.
      # @return [Submit] A new instance of Submit.
      def initialize(code:, name: nil, description: nil, categories: nil, filename: nil,
                     auto_describe: true, auto_categorize: true)
        @code = code
        @name = name
        @description = description
        @categories = categories || []
        @filename = filename
        @auto_describe = auto_describe
        @auto_categorize = auto_categorize
        @db = BlueprintsCLI::BlueprintDatabase.new

        # Detect types based on filename using Blueprint model method
        @types = ::Blueprint.detect_types(@filename)
      end

      ##
      # Executes the blueprint submission process. This includes generating missing metadata,
      # validating the blueprint data, and creating the blueprint in the database.
      #
      # @return [Boolean] true if the blueprint was successfully created, false otherwise.
      # @raise [StandardError] If an error occurs during the submission process.
      def call
        BlueprintsCLI.logger.step('Processing blueprint submission...')

        # Generate missing metadata using AI
        generate_missing_metadata

        # Validate required fields
        return false unless validate_blueprint_data

        # Create the blueprint in database
        blueprint = @db.create_blueprint(
          code: @code,
          name: @name,
          description: @description,
          categories: @categories,
          language: @types[:language],
          file_type: @types[:file_type],
          blueprint_type: @types[:blueprint_type],
          parser_type: @types[:parser_type]
        )

        if blueprint
          BlueprintsCLI.logger.success('Blueprint created successfully!')
          display_blueprint_summary(blueprint)
          true
        else
          BlueprintsCLI.logger.failure('Failed to create blueprint')
          false
        end
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error submitting blueprint: #{e.message}")
        BlueprintsCLI.logger.debug(e) if ENV['DEBUG']
        false
      end

      private

      ##
      # Generates missing metadata for the blueprint, including name, description, and categories.
      #
      # @return [void]
      def generate_missing_metadata
        # Generate name if not provided
        if @name.nil? || @name.strip.empty?
          BlueprintsCLI.logger.info('Generating blueprint name...')
          @name = BlueprintsCLI::Generators::Name.new(
            code: @code,
            description: @description
          ).generate
          puts "   Generated name: #{@name}".colorize(:cyan)
        end

        # Generate description if not provided and auto_describe is enabled
        if (@description.nil? || @description.strip.empty?) && @auto_describe
          puts '📖 Generating blueprint description...'.colorize(:yellow)
          @description = BlueprintsCLI::Generators::Description.new(
            code: @code
          ).generate
          puts "   Generated description: #{truncate_text(@description, 80)}".colorize(:cyan)
        end

        # Generate categories if not provided and auto_categorize is enabled
        return unless @categories.empty? && @auto_categorize

        puts '🏷️  Generating blueprint categories...'.colorize(:yellow)
        @categories = BlueprintsCLI::Generators::Category.new(
          code: @code,
          description: @description
        ).generate
        puts "   Generated categories: #{@categories.join(', ')}".colorize(:cyan)
      end

      ##
      # Validates the blueprint data to ensure all required fields are present and valid.
      #
      # @return [Boolean] true if the blueprint data is valid, false otherwise.
      def validate_blueprint_data
        errors = []

        errors << 'Code cannot be empty' if @code.nil? || @code.strip.empty?

        errors << 'Name is required (auto-generation failed)' if @name.nil? || @name.strip.empty?

        if @description.nil? || @description.strip.empty?
          if @auto_describe
            errors << 'Description generation failed'
          else
            puts '⚠️  Warning: No description provided'.colorize(:yellow)
          end
        end

        if errors.any?
          BlueprintsCLI.logger.failure('Validation errors:')
          errors.each { |error| BlueprintsCLI.logger.error("   - #{error}") }
          return false
        end

        true
      end

      ##
      # Displays a summary of the created blueprint.
      #
      # @param blueprint [Hash] The blueprint data to display.
      # @return [void]
      def display_blueprint_summary(blueprint)
        puts "\n" + '=' * 60
        puts '📋 Blueprint Summary'.colorize(:blue)
        puts '=' * 60
        puts "ID: #{blueprint[:id]}"
        puts "Name: #{blueprint[:name]}"
        puts "Description: #{blueprint[:description]}"
        puts "Language: #{@types[:language]}"
        puts "File Type: #{@types[:file_type]}"
        puts "Blueprint Type: #{@types[:blueprint_type]}"
        puts "Parser Type: #{@types[:parser_type]}"

        if blueprint[:categories] && blueprint[:categories].any?
          category_names = blueprint[:categories].map { |cat| cat[:title] }
          puts "Categories: #{category_names.join(', ')}"
        end

        puts "Code length: #{@code.length} characters"
        puts "Created: #{blueprint[:created_at]}"
        puts '=' * 60
        puts ''
      end

      ##
      # Truncates the given text to the specified length.
      #
      # @param text [String] The text to truncate.
      # @param length [Integer] The maximum length of the text.
      # @return [String] The truncated text.
      def truncate_text(text, length)
        return text if text.length <= length

        text[0..length - 4] + '...'
      end
    end
  end
end
