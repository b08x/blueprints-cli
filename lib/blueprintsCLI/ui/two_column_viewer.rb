# frozen_string_literal: true

require 'tty-box'
require 'tty-cursor'
require 'tty-screen'
require_relative '../cli_ui_integration'
require_relative '../slash_command_parser'

module BlueprintsCLI
  module UI
    # TwoColumnViewer provides an enhanced blueprint viewing experience
    # with metadata/details on the left and scrollable code on the right
    class TwoColumnViewer
      ACTIONS = {
        'edit' => '✏️  Edit blueprint',
        'preview' => '👀 Preview improvements',
        'docs' => '📚 Generate documentation',
        'export' => '💾 Export code',
        'copy' => '📋 Copy to clipboard',
        'analyze' => '🤖 AI analysis',
        'back' => '⬅️  Back to list',
        'quit' => '❌ Quit'
      }.freeze

      def initialize(blueprint, with_suggestions: false)
        @blueprint = blueprint
        @with_suggestions = with_suggestions
        @cursor = TTY::Cursor
        @screen_width = TTY::Screen.width
        @screen_height = TTY::Screen.height

        # Calculate column widths (left: 40%, right: 60%)
        @left_width = (@screen_width * 0.4).to_i - 2
        @right_width = (@screen_width * 0.6).to_i - 2
        @content_height = @screen_height - 8 # Reserve space for title and menu

        # Initialize scroll position for code
        @code_scroll_position = 0
        @code_lines = @blueprint[:code].split("\n")
        @visible_code_lines = @content_height - 4 # Account for box borders
      end

      # Display the two-column view
      def display
        clear_screen
        render_layout
        handle_interactions
      end

      private

      def clear_screen
        print @cursor.clear_screen
        print @cursor.move_to(0, 0)
      end

      def render_layout
        render_header
        render_columns
        render_slash_menu
      end

      def render_header
        title = "📋 Blueprint: #{@blueprint[:name]}"
        header_box = TTY::Box.frame(
          title,
          align: :center,
          width: @screen_width - 2,
          style: { border: { fg: :bright_blue } },
          padding: 0
        )
        puts header_box
      end

      def render_columns
        left_content = build_left_column_content
        right_content = build_right_column_content

        # Create side-by-side boxes
        left_box = TTY::Box.frame(
          left_content,
          title: { top_left: '📋 Details' },
          width: @left_width,
          height: @content_height,
          style: { border: { fg: :cyan } },
          padding: 1
        )

        right_box = TTY::Box.frame(
          right_content,
          title: {
            top_left: "💻 Code (#{@blueprint[:language]})",
            top_right: scrollable_indicator
          },
          width: @right_width,
          height: @content_height,
          style: { border: { fg: :green } },
          padding: 1
        )

        # Display boxes side by side
        left_lines = left_box.split("\n")
        right_lines = right_box.split("\n")

        max_lines = [left_lines.length, right_lines.length].max

        (0...max_lines).each do |i|
          left_line = left_lines[i] || (' ' * @left_width)
          right_line = right_lines[i] || (' ' * @right_width)
          puts "#{left_line}#{right_line}"
        end
      end

      def build_left_column_content
        content_parts = []

        # Basic metadata
        content_parts << build_metadata_section
        content_parts << ''

        # Language & file info (move up for visibility)
        content_parts << build_language_info_section
        content_parts << ''

        # Description (more compact)
        content_parts << build_description_section
        content_parts << ''

        # Categories
        content_parts << build_categories_section

        # AI suggestions if available
        if @blueprint[:ai_suggestions]
          content_parts << ''
          content_parts << build_suggestions_section
        end

        # Truncate content to fit in box height
        max_lines = @content_height - 4 # Account for padding and borders
        content_lines = content_parts.join("\n").split("\n")

        if content_lines.length > max_lines
          content_lines = content_lines[0...(max_lines - 1)] + ['... (truncated)']
        end

        content_lines.join("\n")
      end

      def build_metadata_section
        lines = []
        lines << "🆔 ID: #{@blueprint[:id]}"
        lines << "📅 Created: #{format_date(@blueprint[:created_at])}"
        lines << "🔄 Updated: #{format_date(@blueprint[:updated_at])}"
        lines << "📏 Size: #{@blueprint[:code].length} chars"
        lines.join("\n")
      end

      def build_description_section
        description = @blueprint[:description] || 'No description available'

        # Truncate long descriptions to save space
        description = "#{description[0...147]}..." if description.length > 150

        wrapped_description = wrap_text(description, @left_width - 4)

        "📝 Description:\n#{wrapped_description}"
      end

      def build_language_info_section
        lines = []
        lines << "🔤 Language: #{@blueprint[:language] || 'Unknown'}"
        lines << "📄 File Type: #{@blueprint[:file_type] || 'N/A'}"
        lines << "📦 Type: #{@blueprint[:blueprint_type] || 'N/A'}"
        lines << "⚙️  Parser: #{@blueprint[:parser_type] || 'N/A'}"
        lines.join("\n")
      end

      def build_categories_section
        if @blueprint[:categories]&.any?
          category_names = @blueprint[:categories].map { |cat| cat[:title] || cat[:name] }
          categories_text = category_names.join(', ')
          wrapped_categories = wrap_text(categories_text, @left_width - 4)
          "🏷️  Categories:\n#{wrapped_categories}"
        else
          '🏷️  Categories: None'
        end
      end

      def build_suggestions_section
        suggestions = @blueprint[:ai_suggestions]
        lines = []
        lines << '🤖 AI Analysis:'

        if suggestions[:improvements]
          lines << 'Improvements:'
          suggestions[:improvements].each do |improvement|
            wrapped = wrap_text("• #{improvement}", @left_width - 6)
            lines << wrapped
          end
        end

        if suggestions[:quality_assessment]
          lines << ''
          lines << 'Quality:'
          wrapped_quality = wrap_text(suggestions[:quality_assessment], @left_width - 4)
          lines << wrapped_quality
        end

        lines.join("\n")
      end

      def build_right_column_content
        visible_lines = get_visible_code_lines
        get_line_numbers(visible_lines.length)

        # Add line numbers to code
        numbered_lines = visible_lines.map.with_index do |line, index|
          line_num = (@code_scroll_position + index + 1).to_s.rjust(3)
          "#{line_num} │ #{line}"
        end

        # Ensure lines fit in the right column width
        max_code_width = @right_width - 8 # Account for line numbers and padding
        formatted_lines = numbered_lines.map do |line|
          if line.length > max_code_width
            "#{line[0...(max_code_width - 3)]}..."
          else
            line
          end
        end

        formatted_lines.join("\n")
      end

      def get_visible_code_lines
        start_line = @code_scroll_position
        end_line = [@code_scroll_position + @visible_code_lines, @code_lines.length].min

        @code_lines[start_line...end_line] || []
      end

      def get_line_numbers(count)
        start_num = @code_scroll_position + 1
        (start_num...(start_num + count)).to_a
      end

      def scrollable_indicator
        if @code_lines.length > @visible_code_lines
          total_lines = @code_lines.length
          current_line = @code_scroll_position + 1
          end_line = [@code_scroll_position + @visible_code_lines, total_lines].min
          "#{current_line}-#{end_line}/#{total_lines}"
        else
          "#{@code_lines.length} lines"
        end
      end

      def render_slash_menu
        actions_text = ACTIONS.map { |key, desc| "/#{key}: #{desc}" }.join('  |  ')

        menu_box = TTY::Box.frame(
          "#{actions_text}\n\n💡 Use arrow keys to scroll code, type /command to execute actions",
          title: { top_left: '⚡ Quick Actions' },
          width: @screen_width - 2,
          style: { border: { fg: :yellow } },
          padding: 1
        )
        puts menu_box
      end

      def handle_interactions
        CLIUIIntegration.puts('{{blue:Press Enter to continue or type a slash command...}}')

        loop do
          input = gets.chomp.strip

          if input.empty?
            break
          elsif input.start_with?('/')
            handle_slash_command(input)
          else
            CLIUIIntegration.puts('{{yellow:Unknown command. Use /help for available commands.}}')
          end
        end
      end

      def handle_slash_command(command)
        command_parts = command[1..].split
        action = command_parts.first&.downcase

        case action
        when 'edit'
          handle_edit_action
        when 'preview'
          handle_preview_action
        when 'docs'
          handle_docs_action
        when 'export'
          handle_export_action
        when 'copy'
          handle_copy_action
        when 'analyze'
          handle_analyze_action
        when 'back'
          :back
        when 'quit', 'exit'
          :quit
        when 'scroll'
          handle_scroll_action(command_parts[1])
        when 'help'
          show_help
        else
          CLIUIIntegration.puts("{{red:Unknown action: #{action}}}")
          CLIUIIntegration.puts("{{yellow:Available actions: #{ACTIONS.keys.join(', ')}}}")
        end
      end

      def handle_edit_action
        CLIUIIntegration.puts("{{blue:🔄 Launching edit action for blueprint #{@blueprint[:id]}...}}")
        # Integration with existing edit command
        result = BlueprintsCLI::Actions::Edit.new(id: @blueprint[:id]).call
        CLIUIIntegration.puts(result ? '{{green:✅ Edit completed}}' : '{{red:❌ Edit failed}}')
      end

      def handle_preview_action
        CLIUIIntegration.puts('{{blue:🔄 Generating preview improvements...}}')
        if @blueprint[:ai_suggestions]
          display_improvements_preview
        else
          generate_and_display_improvements
        end
      end

      def handle_docs_action
        CLIUIIntegration.puts('{{blue:🔄 Generating documentation...}}')
        begin
          # Create a temporary file with the blueprint code
          require 'tempfile'
          temp_file = Tempfile.new(["blueprint_#{@blueprint[:id]}",
            @blueprint[:file_type] || '.rb'])
          temp_file.write(@blueprint[:code])
          temp_file.close

          # Use the docs command to generate documentation
          docs_command = BlueprintsCLI::Commands::DocsCommand.new({})
          result = docs_command.execute('generate', temp_file.path)

          CLIUIIntegration.puts(result ? '{{green:✅ Documentation generated}}' : '{{red:❌ Documentation generation failed}}')
        rescue StandardError => e
          CLIUIIntegration.puts("{{red:❌ Documentation failed: #{e.message}}}")
        ensure
          temp_file&.unlink # Clean up temp file
        end
      end

      def handle_export_action
        CLIUIIntegration.puts('{{blue:🔄 Exporting blueprint...}}')
        result = BlueprintsCLI::Actions::Export.new(
          id: @blueprint[:id],
          output_path: nil
        ).call
        CLIUIIntegration.puts(result ? '{{green:✅ Export completed}}' : '{{red:❌ Export failed}}')
      end

      def handle_copy_action
        if system('which pbcopy > /dev/null 2>&1') # macOS
          IO.popen('pbcopy', 'w') { |pipe| pipe.write(@blueprint[:code]) }
          CLIUIIntegration.puts('{{green:✅ Code copied to clipboard (macOS)}}')
        elsif system('which wl-copy > /dev/null 2>&1') # Linux
          IO.popen('wl-copy', 'w') { |pipe| pipe.write(@blueprint[:code]) }
          CLIUIIntegration.puts('{{green:✅ Code copied to clipboard (Linux)}}')
        elsif system('which xclip > /dev/null 2>&1') # Linux
          IO.popen('xclip -selection clipboard', 'w') { |pipe| pipe.write(@blueprint[:code]) }
          CLIUIIntegration.puts('{{green:✅ Code copied to clipboard (Linux)}}')
        else
          CLIUIIntegration.puts('{{yellow:⚠️  Clipboard not available. Code printed below:}}')
          puts @blueprint[:code]
        end
      end

      def handle_analyze_action
        CLIUIIntegration.puts('{{blue:🔄 Running AI analysis...}}')
        # Generate AI suggestions if not already available
        @blueprint[:ai_suggestions] = generate_ai_suggestions unless @blueprint[:ai_suggestions]

        clear_screen
        render_layout # Re-render with suggestions
      end

      def handle_scroll_action(direction)
        case direction&.downcase
        when 'up'
          @code_scroll_position = [@code_scroll_position - 5, 0].max
        when 'down'
          max_scroll = [@code_lines.length - @visible_code_lines, 0].max
          @code_scroll_position = [@code_scroll_position + 5, max_scroll].min
        when 'top'
          @code_scroll_position = 0
        when 'bottom'
          @code_scroll_position = [@code_lines.length - @visible_code_lines, 0].max
        else
          CLIUIIntegration.puts('{{yellow:Usage: /scroll [up|down|top|bottom]}}')
          return
        end

        clear_screen
        render_layout
      end

      def show_help
        help_text = <<~HELP
          🔧 Available Commands:

          /edit        - Edit this blueprint
          /preview     - Preview AI improvements#{'  '}
          /docs        - Generate documentation
          /export      - Export code to file
          /copy        - Copy code to clipboard
          /analyze     - Run AI analysis
          /scroll up   - Scroll code up
          /scroll down - Scroll code down
          /back        - Return to blueprint list
          /quit        - Exit application

          💡 Tips:
          - Use arrow keys for navigation
          - Code panel shows line numbers
          - Scroll indicator shows current position
        HELP

        CLIUIIntegration.puts(help_text)
      end

      # Helper methods
      def format_date(timestamp)
        return 'N/A' unless timestamp

        Time.parse(timestamp.to_s).strftime('%Y-%m-%d %H:%M')
      rescue StandardError
        timestamp.to_s
      end

      def wrap_text(text, width)
        return '' if text.nil? || text.empty?

        text.gsub(/(.{1,#{width - 1}})(\s+|$)/, "\\1\n").strip
      end

      def display_improvements_preview
        suggestions = @blueprint[:ai_suggestions]
        return unless suggestions[:improvements]

        CLIUIIntegration.frame('🔮 AI Improvement Suggestions', color: :magenta) do
          suggestions[:improvements].each_with_index do |improvement, index|
            CLIUIIntegration.puts("{{green:#{index + 1}.}} #{improvement}")
            CLIUIIntegration.puts('')
          end
        end
      end

      def generate_and_display_improvements
        suggestions = BlueprintsCLI::Generators::Improvement.new(
          code: @blueprint[:code],
          description: @blueprint[:description]
        ).generate

        @blueprint[:ai_suggestions] = { improvements: suggestions }
        display_improvements_preview

        # Re-render to show suggestions in left panel
        clear_screen
        render_layout
      rescue StandardError => e
        CLIUIIntegration.puts("{{red:❌ Failed to generate improvements: #{e.message}}}")
      end

      def generate_ai_suggestions
        suggestions = BlueprintsCLI::Generators::Improvement.new(
          code: @blueprint[:code],
          description: @blueprint[:description]
        ).generate

        { improvements: suggestions }
      rescue StandardError => e
        BlueprintsCLI.logger.warn("AI suggestions failed: #{e.message}")
        nil
      end
    end
  end
end
