# frozen_string_literal: true

require 'tty-box'
require_relative '../ui/preview_boxes'
require_relative '../ui/two_column_viewer'
require_relative '../ui/cli_ui_viewer'

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
          begin
            blueprint[:ai_suggestions] = generate_suggestions(blueprint)
          rescue StandardError => e
            BlueprintsCLI.logger.warn("AI suggestions failed: #{e.message}")
            puts "⚠️  AI analysis unavailable: #{e.message}".colorize(:yellow)
            blueprint[:ai_suggestions] = nil
          end
        end

        case @format
        when :detailed
          display_detailed(blueprint)
        when :interactive
          display_interactive(blueprint)
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
        BlueprintsCLI.logger.error("Stack trace: #{e.backtrace.join("\n")}")
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
      # Displays an interactive view of the blueprint using CLI::UI.
      #
      # Shows metadata and details in organized sections with scrollable code,
      # and a slash menu for actions like edit, preview improvements, generate docs.
      #
      # @param blueprint [Hash] The blueprint data to display
      # @return [void]
      #
      # @example Internal usage
      #   display_interactive(blueprint_data)
      def display_interactive(blueprint)
        viewer = BlueprintsCLI::UI::CLIUIViewer.new(
          blueprint,
          with_suggestions: @with_suggestions
        )
        viewer.display
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
        content_parts = []

        # Metadata Box
        metadata_content = build_metadata_content(blueprint)
        metadata_box = TTY::Box.frame(
          metadata_content,
          title: { top_left: '📋 Blueprint Details' },
          style: { border: { fg: :blue } },
          padding: 1
        )
        content_parts << metadata_box

        # Description Box
        description_content = blueprint[:description] || 'No description available'
        description_box = TTY::Box.frame(
          description_content,
          title: { top_left: '📝 Description' },
          style: { border: { fg: :cyan } },
          width: 120,
          padding: 1
        )
        content_parts << description_box

        # AI Suggestions Box (if available)
        if blueprint[:ai_suggestions]
          suggestions_content = build_suggestions_content(blueprint[:ai_suggestions])
          suggestions_box = TTY::Box.frame(
            suggestions_content,
            title: { top_left: '🤖 AI Analysis & Suggestions' },
            style: { border: { fg: :magenta } },
            width: 140,
            padding: 1
          )
          content_parts << suggestions_box
        end

        # Code Box with plain text (syntax highlighting removed due to readability issues)
        code_box = UI::PreviewBoxes.code_box(
          blueprint[:code],
          title: '💻 Blueprint Code'
        )
        content_parts << code_box

        content_parts.join("\n\n")
      end

      ##
      # Builds metadata content for the metadata box.
      #
      # @param blueprint [Hash] The blueprint data
      # @return [String] Formatted metadata content
      def build_metadata_content(blueprint)
        metadata_lines = []
        metadata_lines << "ID: #{blueprint[:id]}"
        metadata_lines << "Name: #{blueprint[:name]}"
        metadata_lines << "Created: #{blueprint[:created_at]}"
        metadata_lines << "Updated: #{blueprint[:updated_at]}"

        # Categories
        if blueprint[:categories] && blueprint[:categories].any?
          category_names = blueprint[:categories].map { |cat| cat[:title] }
          metadata_lines << "Categories: #{category_names.join(', ')}"
        else
          metadata_lines << 'Categories: None'
        end

        metadata_lines.join("\n")
      end

      ##
      # Builds AI suggestions content for the suggestions box.
      #
      # @param suggestions [Hash] The AI suggestions data
      # @return [String] Formatted suggestions content
      def build_suggestions_content(suggestions)
        content_lines = []

        if suggestions[:improvements]
          content_lines << '💡 Improvements:'
          suggestions[:improvements].each do |improvement|
            # Wrap long improvement text to fit in box (130 chars for width 140 box)
            wrapped_improvement = wrap_text(improvement, 130)
            # Indent continuation lines
            wrapped_lines = wrapped_improvement.split("\n")
            content_lines << "  • #{wrapped_lines.first}"
            wrapped_lines[1..].each { |line| content_lines << "    #{line}" }
          end
          content_lines << ''
        end

        if suggestions[:quality_assessment]
          content_lines << '📊 Quality Assessment:'
          wrapped_assessment = wrap_text(suggestions[:quality_assessment], 130)
          content_lines << wrapped_assessment
        end

        content_lines.join("\n")
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
      # Simple text wrapping helper
      #
      # @param text [String] Text to wrap
      # @param width [Integer] Maximum line width
      # @return [String] Wrapped text
      def wrap_text(text, width = 80)
        text.gsub(/(.{1,#{width}})(\s+|$)/, "\\1\n").strip
      end

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
