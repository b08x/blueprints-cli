# frozen_string_literal: true

require_relative '../cli_ui_integration'
require_relative '../slash_command_parser'

module BlueprintsCLI
  module UI
    # CLIUIViewer provides an enhanced blueprint viewing experience using CLI::UI
    # with metadata/details on the left and scrollable code on the right
    class CLIUIViewer
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
        @code_scroll_position = 0
        @code_lines = @blueprint[:code].split("\n")
        @lines_per_page = 20 # Show 20 lines at a time

        CLIUIIntegration.initialize!
      end

      # Display the CLI::UI based view
      def display
        show_blueprint_header
        show_details_section
        show_code_section
        show_actions_menu
        handle_interactions
      end

      private

      def show_blueprint_header
        CLIUIIntegration.frame("📋 Blueprint: #{@blueprint[:name]}", color: :cyan) do
          CLIUIIntegration.puts("{{blue:ID: #{@blueprint[:id]}}} | {{green:Language: #{@blueprint[:language] || 'Unknown'}}} | {{yellow:Size: #{@blueprint[:code].length} chars}}")
        end
        CLIUIIntegration.puts('')
      end

      def show_details_section
        CLIUIIntegration.frame('📋 Blueprint Details', color: :blue) do
          show_metadata_info
          CLIUIIntegration.puts('')
          show_language_info
          CLIUIIntegration.puts('')
          show_description
          CLIUIIntegration.puts('')
          show_categories

          if @blueprint[:ai_suggestions]
            CLIUIIntegration.puts('')
            show_ai_suggestions
          end
        end
        CLIUIIntegration.puts('')
      end

      def show_metadata_info
        CLIUIIntegration.puts("{{bold:📅 Created:}} #{format_date(@blueprint[:created_at])}")
        CLIUIIntegration.puts("{{bold:🔄 Updated:}} #{format_date(@blueprint[:updated_at])}")
        CLIUIIntegration.puts("{{bold:📏 Size:}} #{@blueprint[:code].length} characters")
      end

      def show_language_info
        CLIUIIntegration.puts("{{bold:🔤 Language:}} {{green:#{@blueprint[:language] || 'Unknown'}}}")
        CLIUIIntegration.puts("{{bold:📄 File Type:}} {{cyan:#{@blueprint[:file_type] || 'N/A'}}}")
        CLIUIIntegration.puts("{{bold:📦 Blueprint Type:}} {{magenta:#{@blueprint[:blueprint_type] || 'N/A'}}}")
        CLIUIIntegration.puts("{{bold:⚙️  Parser Type:}} {{yellow:#{@blueprint[:parser_type] || 'N/A'}}}")
      end

      def show_description
        description = @blueprint[:description] || 'No description available'
        CLIUIIntegration.puts('{{bold:📝 Description:}}')
        CLIUIIntegration.puts(description)
      end

      def show_categories
        if @blueprint[:categories]&.any?
          category_names = @blueprint[:categories].map { |cat| cat[:title] || cat[:name] }
          categories_text = category_names.join(', ')
          CLIUIIntegration.puts("{{bold:🏷️  Categories:}} {{blue:#{categories_text}}}")
        else
          CLIUIIntegration.puts('{{bold:🏷️  Categories:}} {{gray:None}}')
        end
      end

      def show_ai_suggestions
        suggestions = @blueprint[:ai_suggestions]
        CLIUIIntegration.puts('{{bold:🤖 AI Analysis:}}')

        if suggestions[:improvements]
          CLIUIIntegration.puts('{{green:💡 Improvements:}}')
          suggestions[:improvements].each_with_index do |improvement, index|
            CLIUIIntegration.puts("  {{blue:#{index + 1}.}} #{improvement}")
          end
        end

        return unless suggestions[:quality_assessment]

        CLIUIIntegration.puts('')
        CLIUIIntegration.puts('{{yellow:📊 Quality Assessment:}}')
        CLIUIIntegration.puts(suggestions[:quality_assessment])
      end

      def show_code_section
        visible_lines = get_visible_code_lines
        scroll_info = get_scroll_info

        CLIUIIntegration.frame("💻 Code (#{@blueprint[:language]}) - #{scroll_info}",
                               color: :green) do
          if visible_lines.empty?
            CLIUIIntegration.puts('{{gray:No code available}}')
          else
            visible_lines.each_with_index do |line, index|
              line_num = (@code_scroll_position + index + 1).to_s.rjust(3)
              formatted_line = line.length > 80 ? "#{line[0...77]}..." : line
              CLIUIIntegration.puts("{{gray:#{line_num} |}} #{formatted_line}")
            end
          end
        end
        CLIUIIntegration.puts('')
      end

      def show_actions_menu
        actions_list = ACTIONS.map { |key, desc| "{{blue:/#{key}}} - #{desc}" }.join("\n")

        CLIUIIntegration.frame('⚡ Quick Actions', color: :yellow) do
          CLIUIIntegration.puts(actions_list)
          CLIUIIntegration.puts('')
          CLIUIIntegration.puts('{{bold:💡 Navigation:}} Use {{blue:/scroll up}}/{{blue:/scroll down}} to navigate code')
          CLIUIIntegration.puts('{{bold:📖 Usage:}} Type a command (e.g., {{blue:/edit}}) or press Enter to continue')
        end
      end

      def handle_interactions
        loop do
          CLIUIIntegration.puts('')
          CLIUIIntegration.puts('{{blue:Enter command or press Enter to continue:}}')

          input = $stdin.gets.chomp.strip

          if input.empty?
            break
          elsif input.start_with?('/')
            result = handle_slash_command(input)
            break if %i[quit back].include?(result)
          else
            CLIUIIntegration.puts('{{yellow:⚠️  Unknown command. Use /help for available commands.}}')
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
        when 'scroll'
          handle_scroll_action(command_parts[1])
        when 'back'
          :back
        when 'quit', 'exit'
          :quit
        when 'help'
          show_help
        else
          CLIUIIntegration.puts("{{red:❌ Unknown action: #{action}}}")
          CLIUIIntegration.puts("{{yellow:Available actions: #{ACTIONS.keys.join(', ')}}}")
        end
      end

      def handle_edit_action
        CLIUIIntegration.puts("{{blue:🔄 Launching edit action for blueprint #{@blueprint[:id]}...}}")
        begin
          result = BlueprintsCLI::Actions::Edit.new(id: @blueprint[:id]).call
          CLIUIIntegration.puts(result ? '{{green:✅ Edit completed}}' : '{{red:❌ Edit failed}}')
        rescue StandardError => e
          CLIUIIntegration.puts("{{red:❌ Edit failed: #{e.message}}}")
        end
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
        begin
          result = BlueprintsCLI::Actions::Export.new(
            id: @blueprint[:id],
            output_path: nil
          ).call
          CLIUIIntegration.puts(result ? '{{green:✅ Export completed}}' : '{{red:❌ Export failed}}')
        rescue StandardError => e
          CLIUIIntegration.puts("{{red:❌ Export failed: #{e.message}}}")
        end
      end

      def handle_copy_action
        if system('which pbcopy > /dev/null 2>&1') # macOS
          IO.popen('pbcopy', 'w') { |pipe| pipe.write(@blueprint[:code]) }
          CLIUIIntegration.puts('{{green:✅ Code copied to clipboard (macOS)}}')
        elsif system('which xclip > /dev/null 2>&1') # Linux
          IO.popen('xclip -selection clipboard', 'w') { |pipe| pipe.write(@blueprint[:code]) }
          CLIUIIntegration.puts('{{green:✅ Code copied to clipboard (Linux)}}')
        else
          CLIUIIntegration.puts('{{yellow:⚠️  Clipboard not available. Code printed below:}}')
          puts @blueprint[:code]
        end
      rescue StandardError => e
        CLIUIIntegration.puts("{{red:❌ Copy failed: #{e.message}}}")
      end

      def handle_analyze_action
        CLIUIIntegration.puts('{{blue:🔄 Running AI analysis...}}')
        begin
          # Generate AI suggestions if not already available
          @blueprint[:ai_suggestions] = generate_ai_suggestions unless @blueprint[:ai_suggestions]

          # Refresh the display
          CLIUIIntegration.puts('')
          show_details_section
          CLIUIIntegration.puts('{{green:✅ AI analysis completed}}')
        rescue StandardError => e
          CLIUIIntegration.puts("{{red:❌ AI analysis failed: #{e.message}}}")
        end
      end

      def handle_scroll_action(direction)
        case direction&.downcase
        when 'up'
          @code_scroll_position = [@code_scroll_position - 10, 0].max
        when 'down'
          max_scroll = [@code_lines.length - @lines_per_page, 0].max
          @code_scroll_position = [@code_scroll_position + 10, max_scroll].min
        when 'top'
          @code_scroll_position = 0
        when 'bottom'
          @code_scroll_position = [@code_lines.length - @lines_per_page, 0].max
        else
          CLIUIIntegration.puts('{{yellow:Usage: /scroll [up|down|top|bottom]}}')
          return
        end

        CLIUIIntegration.puts('')
        show_code_section
      end

      def show_help
        CLIUIIntegration.frame('🔧 Available Commands', color: :magenta) do
          ACTIONS.each do |key, desc|
            CLIUIIntegration.puts("{{blue:/#{key.ljust(8)}}} - #{desc}")
          end
          CLIUIIntegration.puts('')
          CLIUIIntegration.puts('{{bold:💡 Tips:}}')
          CLIUIIntegration.puts('• Use {{blue:/scroll up}} and {{blue:/scroll down}} to navigate code')
          CLIUIIntegration.puts('• Code panel automatically truncates long lines')
          CLIUIIntegration.puts('• Language detection works for 25+ programming languages')
        end
      end

      # Helper methods
      def get_visible_code_lines
        start_line = @code_scroll_position
        end_line = [@code_scroll_position + @lines_per_page, @code_lines.length].min

        @code_lines[start_line...end_line] || []
      end

      def get_scroll_info
        if @code_lines.length <= @lines_per_page
          "#{@code_lines.length} lines"
        else
          current_line = @code_scroll_position + 1
          end_line = [@code_scroll_position + @lines_per_page, @code_lines.length].min
          "Lines #{current_line}-#{end_line} of #{@code_lines.length}"
        end
      end

      def format_date(timestamp)
        return 'N/A' unless timestamp

        Time.parse(timestamp.to_s).strftime('%Y-%m-%d %H:%M')
      rescue StandardError
        timestamp.to_s
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
      rescue StandardError => e
        CLIUIIntegration.puts("{{red:❌ Failed to generate improvements: #{e.message}}}")
        BlueprintsCLI.logger.error("AI improvement generation failed: #{e.message}")
      end

      def generate_ai_suggestions
        suggestions = BlueprintsCLI::Generators::Improvement.new(
          code: @blueprint[:code],
          description: @blueprint[:description]
        ).generate

        { improvements: suggestions }
      rescue StandardError => e
        BlueprintsCLI.logger.warn("AI suggestions failed: #{e.message}")
        CLIUIIntegration.puts("{{yellow:⚠️  AI suggestions unavailable: #{e.message}}}")
        nil
      end
    end
  end
end
