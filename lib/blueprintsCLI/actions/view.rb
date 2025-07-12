# frozen_string_literal: true

module BlueprintsCLI
  module Actions
    ##
    # Action class for viewing blueprint details with various output formats.
    #
    # This class provides functionality to fetch and display blueprints from the database
    # with options for different output formats and AI-generated suggestions.
    #
    # Primary usage scenarios:
    # - Viewing detailed blueprint information
    # - Getting a quick summary of a blueprint
    # - Retrieving just the code portion of a blueprint
    # - Obtaining blueprint data in JSON format
    # - Getting AI-powered suggestions for blueprint improvements
    class View < Sublayer::Actions::Base
      ##
      # Initializes a new View instance.
      #
      # @param id [Integer] The ID of the blueprint to view
      # @param format [Symbol] The output format (:detailed, :json, :code_only, or :summary)
      # @param with_suggestions [Boolean] Whether to generate AI suggestions for the blueprint
      # @return [View] A new instance of View
      #
      # @example Basic initialization
      #   action = View.new(id: 123, format: :detailed)
      #
      # @example With AI suggestions
      #   action = View.new(id: 123, format: :detailed, with_suggestions: true)
      def initialize(id:, format: :detailed, with_suggestions: false)
        @id = id
        @format = format
        @with_suggestions = with_suggestions
        @db = BlueprintsCLI::BlueprintDatabase.new
      end

      ##
      # Executes the blueprint viewing action.
      #
      # Fetches the blueprint from the database, optionally generates AI suggestions,
      # and displays the blueprint according to the specified format.
      #
      # @return [Boolean] true if the operation succeeded, false otherwise
      #
      # @example Basic usage
      #   action = View.new(id: 123)
      #   action.call # => true
      #
      # @example With error handling
      #   action = View.new(id: 999) # Non-existent ID
      #   action.call # => false
      def call
        puts "🔍 Fetching blueprint #{@id}...".colorize(:blue)

        blueprint = @db.get_blueprint(@id)
        unless blueprint
          BlueprintsCLI.logger.failure("Blueprint #{@id} not found")
          return false
        end

        # Generate AI suggestions if requested
        if @with_suggestions
          puts '🤖 Generating AI analysis...'.colorize(:yellow)
          blueprint[:ai_suggestions] = generate_suggestions(blueprint)
        end

        case @format
        when :detailed
          display_detailed(blueprint)
        when :json
          puts JSON.pretty_generate(blueprint)
        when :code_only
          puts blueprint[:code]
        when :summary
          display_summary(blueprint)
        end

        true
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error viewing blueprint: #{e.message}")
        BlueprintsCLI.logger.debug(e) if ENV['DEBUG']
        false
      end

      private

      ##
      # Displays a detailed view of the blueprint.
      #
      # Uses a pager if available for better readability of long content.
      #
      # @param blueprint [Hash] The blueprint data to display
      # @return [void]
      #
      # @example Internal usage
      #   display_detailed(blueprint_data)
      def display_detailed(blueprint)
        content = build_detailed_content(blueprint)

        if tty_pager_available?
          TTY::Pager.page(content)
        else
          puts content
        end
      end

      ##
      # Builds the detailed content for a blueprint.
      #
      # Constructs a comprehensive view of the blueprint including metadata,
      # description, AI suggestions (if available), and the actual code.
      #
      # @param blueprint [Hash] The blueprint data to format
      # @return [String] The formatted content ready for display
      #
      # @example Internal usage
      #   content = build_detailed_content(blueprint_data)
      def build_detailed_content(blueprint)
        content = []
        content << '=' * 80
        content << '📋 Blueprint Details'.colorize(:blue).to_s
        content << '=' * 80
        content << "ID: #{blueprint[:id]}"
        content << "Name: #{blueprint[:name]}"
        content << "Created: #{blueprint[:created_at]}"
        content << "Updated: #{blueprint[:updated_at]}"
        content << ''

        # Categories
        if blueprint[:categories] && blueprint[:categories].any?
          category_names = blueprint[:categories].map { |cat| cat[:title] }
          content << "Categories: #{category_names.join(', ')}"
        else
          content << 'Categories: None'
        end
        content << ''

        # Description
        content << 'Description:'
        content << blueprint[:description] || 'No description available'
        content << ''

        # AI Suggestions (if available)
        if blueprint[:ai_suggestions]
          content << '🤖 AI Analysis & Suggestions:'.colorize(:cyan).to_s
          content << '-' * 40

          if blueprint[:ai_suggestions][:improvements]
            content << '💡 Improvements:'.colorize(:yellow).to_s
            blueprint[:ai_suggestions][:improvements].each do |improvement|
              content << "  • #{improvement}"
            end
            content << ''
          end

          if blueprint[:ai_suggestions][:quality_assessment]
            content << '📊 Quality Assessment:'.colorize(:yellow).to_s
            content << blueprint[:ai_suggestions][:quality_assessment]
            content << ''
          end
        end

        # Code
        content << '-' * 80
        content << '💻 Code:'.colorize(:green).to_s
        content << '-' * 80
        content << blueprint[:code]
        content << '=' * 80

        content.join("\n")
      end

      ##
      # Displays a summary view of the blueprint.
      #
      # Shows key information about the blueprint in a condensed format.
      #
      # @param blueprint [Hash] The blueprint data to summarize
      # @return [void]
      #
      # @example Internal usage
      #   display_summary(blueprint_data)
      def display_summary(blueprint)
        puts "\n📋 Blueprint Summary".colorize(:blue)
        puts '=' * 50
        puts "ID: #{blueprint[:id]}"
        puts "Name: #{blueprint[:name]}"
        puts "Description: #{truncate_text(blueprint[:description] || 'No description', 60)}"

        if blueprint[:categories] && blueprint[:categories].any?
          category_names = blueprint[:categories].map { |cat| cat[:title] }
          puts "Categories: #{category_names.join(', ')}"
        end

        puts "Code length: #{blueprint[:code].length} characters"
        puts "Created: #{blueprint[:created_at]}"
        puts '=' * 50
        puts ''
      end

      ##
      # Generates AI-powered suggestions for blueprint improvements.
      #
      # Uses the Improvement to analyze the blueprint code
      # and description, then returns improvement suggestions.
      #
      # @param blueprint [Hash] The blueprint data to analyze
      # @return [Hash] A hash containing AI suggestions including improvements and quality assessment
      #
      # @example Internal usage
      #   suggestions = generate_suggestions(blueprint_data)
      #   # => { improvements: [...], quality_assessment: "..." }
      def generate_suggestions(blueprint)
        suggestions = {}

        begin
          # Generate improvement suggestions
          improvements = BlueprintsCLI::Generators::Improvement.new(
            code: blueprint[:code],
            description: blueprint[:description]
          ).generate

          suggestions[:improvements] = improvements if improvements
        rescue StandardError => e
          BlueprintsCLI.logger.warn("Could not generate AI suggestions: #{e.message}")
        end

        suggestions
      end

      ##
      # Truncates text to a specified length.
      #
      # Adds ellipsis to the end if the text is longer than the specified length.
      #
      # @param text [String] The text to truncate
      # @param length [Integer] The maximum length of the text
      # @return [String] The truncated text
      #
      # @example Basic usage
      #   truncate_text("This is a long text that needs truncation", 20)
      #   # => "This is a long text..."
      def truncate_text(text, length)
        return text if text.length <= length

        text[0..length - 4] + '...'
      end

      ##
      # Checks if TTY pager is available.
      #
      # @return [Boolean] true if TTY::Pager is defined and available, false otherwise
      #
      # @example Internal usage
      #   if tty_pager_available?
      #     TTY::Pager.page(content)
      #   else
      #     puts content
      #   end
      def tty_pager_available?
        defined?(TTY::Pager)
      end
    end
  end
end
