# frozen_string_literal: true

module BlueprintsCLI
  module Actions
    # Facilitates the interactive editing of an existing blueprint.
    #
    # This action provides a complete workflow for modifying a blueprint's code.
    # It fetches the blueprint by its ID, opens its code in the user's
    # preferred command-line editor (e.g., vim, nano), and waits for changes.
    #
    # Upon saving, it confirms the changes with the user and then performs a
    # "delete-and-resubmit" operation. This ensures that the modified code
    # gets new embeddings and a fresh AI-generated description, keeping the
    # search index up-to-date.
    class Edit < Sublayer::Actions::Base
      # Initializes the action with the ID of the blueprint to be edited.
      #
      # @param id [String, Integer] The unique identifier of the blueprint to edit.
      def initialize(id:)
        @id = id
        @db = BlueprintsCLI::Wrappers::BlueprintDatabase.new
      end

      # Executes the blueprint editing workflow.
      #
      # This method orchestrates the entire process:
      # 1. Fetches the blueprint from the database.
      # 2. Creates a temporary file with the blueprint's code.
      # 3. Launches the user's configured editor to modify the file.
      # 4. If changes are detected, it prompts the user for confirmation.
      # 5. If confirmed, it deletes the original blueprint and creates a new one
      #    with the modified code.
      #
      # @return [Boolean] Returns `true` if the edit was successful or if no
      #   changes were made. Returns `false` if the blueprint is not found,
      #   the editor fails, or the user cancels the operation.
      def call
        # Step 1: Fetch the current blueprint
        blueprint = @db.get_blueprint(@id)
        unless blueprint
          BlueprintsCLI.logger.failure("Blueprint #{@id} not found")
          return false
        end

        puts "✏️  Editing blueprint: #{blueprint[:name]}".colorize(:blue)
        puts "Original description: #{blueprint[:description]}"
        puts "Categories: #{blueprint[:categories].map { |c| c[:title] }.join(', ')}" if blueprint[:categories].any?

        # Step 2: Open editor with current code
        temp_file = create_temp_file(blueprint)

        begin
          # Step 3: Launch editor
          editor_success = launch_editor(temp_file)
          unless editor_success
            puts '❌ Editor failed or was cancelled'.colorize(:red)
            return false
          end

          # Step 4: Read modified content
          modified_code = File.read(temp_file)

          # Step 5: Check if content actually changed
          if modified_code.strip == blueprint[:code].strip
            puts 'ℹ️  No changes detected'.colorize(:blue)
            return true
          end

          puts '✅ Changes detected'.colorize(:green)

          # Step 6: Confirm the edit operation
          unless confirm_edit_operation(blueprint, modified_code)
            puts '❌ Edit operation cancelled'.colorize(:yellow)
            return false
          end

          # Step 7: Execute delete-and-resubmit workflow
          perform_delete_and_resubmit(blueprint, modified_code)
        ensure
          # Clean up temporary file
          File.delete(temp_file) if File.exist?(temp_file)
        end
      rescue StandardError => e
        puts "❌ Error during edit operation: #{e.message}".colorize(:red)
        puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
        false
      end

      private

      # Creates a temporary file containing the blueprint's code.
      #
      # It uses `detect_file_extension` to give the file the appropriate
      # extension, which helps editors with syntax highlighting.
      #
      # @param blueprint [Hash] The blueprint data hash.
      # @return [String] The path to the created temporary file.
      # @private
      def create_temp_file(blueprint)
        # Detect file extension based on code content
        extension = detect_file_extension(blueprint[:code])

        # Create safe filename
        safe_name = blueprint[:name].gsub(/[^a-zA-Z0-9_-]/, '_').downcase
        temp_file = Tempfile.new(["blueprint_#{@id}_#{safe_name}", extension])
        temp_file.write(blueprint[:code])
        temp_file.flush
        temp_file.path
      end

      # Detects the appropriate file extension for a given code snippet.
      #
      # Uses simple regex matching to infer the programming language and
      # returns a corresponding file extension. Defaults to '.txt'.
      #
      # @param code [String] The source code of the blueprint.
      # @return [String] The inferred file extension (e.g., '.rb', '.js').
      # @private
      def detect_file_extension(code)
        case code
        when /class\s+\w+.*<.*ApplicationRecord/m, /def\s+\w+.*end/m, /require ['"].*['"]/m
          '.rb'
        when /function\s+\w+\s*\(/m, /const\s+\w+\s*=/m, /import\s+.*from/m
          '.js'
        when /def\s+\w+\s*\(/m, /import\s+\w+/m, /from\s+\w+\s+import/m
          '.py'
        when /#include\s*<.*>/m, /int\s+main\s*\(/m
          '.c'
        when /public\s+class\s+\w+/m, /import\s+java\./m
          '.java'
        when /fn\s+\w+\s*\(/m, /use\s+std::/m
          '.rs'
        when /func\s+\w+\s*\(/m, /package\s+main/m
          '.go'
        else
          '.txt'
        end
      end

      # Launches the configured system editor to open the temporary file.
      #
      # @param temp_file [String] The path to the file to be opened.
      # @return [Boolean] The success status of the system call.
      # @private
      def launch_editor(temp_file)
        # Get editor preference from config or environment
        editor = get_editor_preference

        puts "🔧 Opening #{editor} with blueprint code...".colorize(:cyan)
        puts '💡 Save and exit when done editing'.colorize(:cyan)

        # Launch editor and wait for it to complete
        system("#{editor} #{temp_file}")
      end

      # Determines the user's preferred editor.
      #
      # It checks for an 'editor' key in `config/blueprints.yml` first,
      # then falls back to the `EDITOR` or `VISUAL` environment variables,
      # and finally defaults to 'vim'.
      #
      # @return [String] The name of the editor command.
      # @private
      def get_editor_preference
        # Check configuration file
        config_file = File.join(__dir__, '..', 'config', 'blueprints.yml')
        if File.exist?(config_file)
          config = YAML.load_file(config_file)
          editor = config.dig('editor')
          return editor if editor
        end

        # Fall back to environment variables
        ENV['EDITOR'] || ENV['VISUAL'] || 'vim'
      end

      # Prompts the user to confirm the destructive edit operation.
      #
      # It displays a warning and a preview of the changes before asking for
      # user input.
      #
      # @param original_blueprint [Hash] The original blueprint data.
      # @param modified_code [String] The code after being edited by the user.
      # @return [Boolean] `true` if the user confirms, `false` otherwise.
      # @private
      def confirm_edit_operation(original_blueprint, modified_code)
        puts "\n" + ('=' * 60)
        puts '🔄 Edit Operation Confirmation'.colorize(:blue)
        puts '=' * 60
        puts "Original blueprint: #{original_blueprint[:name]} (ID: #{@id})"
        puts "Original code length: #{original_blueprint[:code].length} characters"
        puts "Modified code length: #{modified_code.length} characters"
        puts ''
        puts '⚠️  WARNING: This will:'.colorize(:yellow)
        puts '   1. DELETE the existing blueprint (including embeddings)'.colorize(:yellow)
        puts '   2. CREATE a new blueprint with the modified code'.colorize(:yellow)
        puts '   3. Generate NEW embeddings for better search'.colorize(:yellow)
        puts ''

        # Show a preview of changes
        show_change_preview(original_blueprint[:code], modified_code)

        print 'Continue with edit operation? (y/N): '
        response = STDIN.gets.chomp.downcase
        %w[y yes].include?(response)
      end

      # Displays a simple preview of the code changes.
      #
      # Shows the first few lines of the original and modified code to give the
      # user context for the changes they are about to confirm.
      #
      # @param original_code [String] The original, unmodified code.
      # @param modified_code [String] The new, modified code.
      # @return [void]
      # @private
      def show_change_preview(original_code, modified_code)
        puts '📋 Change Preview:'.colorize(:cyan)

        # Show first and last few lines to give context
        original_lines = original_code.lines
        modified_lines = modified_code.lines

        puts 'Original (first 3 lines):'
        original_lines.first(3).each_with_index do |line, i|
          puts "  #{i + 1}: #{line.chomp}"
        end

        puts "\nModified (first 3 lines):"
        modified_lines.first(3).each_with_index do |line, i|
          puts "  #{i + 1}: #{line.chomp}"
        end

        if original_lines.length != modified_lines.length
          puts "\nLine count changed: #{original_lines.length} → #{modified_lines.length}".colorize(:yellow)
        end

        puts ''
      end

      # Executes the core update logic by deleting the old blueprint and
      # submitting a new one.
      #
      # This method reuses `Submit` to handle the creation of the
      # new blueprint, ensuring consistency. It preserves the original name and
      # categories but triggers AI regeneration of the description to match the
      # new code.
      #
      # @param original_blueprint [Hash] The original blueprint data.
      # @param modified_code [String] The new, modified code.
      # @return [Boolean] `true` on success, `false` on failure.
      # @private
      def perform_delete_and_resubmit(original_blueprint, modified_code)
        puts '🔄 Starting delete-and-resubmit workflow...'.colorize(:blue)

        # Store original metadata for rollback
        original_data = {
          name: original_blueprint[:name],
          description: original_blueprint[:description],
          categories: original_blueprint[:categories].map { |c| c[:title] }
        }

        # Step 1: Delete the existing blueprint
        puts '🗑️  Deleting original blueprint...'.colorize(:yellow)
        delete_success = @db.delete_blueprint(@id)

        unless delete_success
          puts '❌ Failed to delete original blueprint. Aborting edit.'.colorize(:red)
          return false
        end

        puts '✅ Original blueprint deleted'.colorize(:green)

        # Step 2: Submit the modified code as a new blueprint
        puts '📝 Creating new blueprint with modified code...'.colorize(:yellow)

        submit_action = BlueprintsCLI::Actions::Submit.new(
          code: modified_code,
          name: original_data[:name], # Keep original name initially
          description: nil, # Let AI regenerate description for modified code
          categories: original_data[:categories], # Keep original categories initially
          auto_describe: true,
          auto_categorize: false # Keep original categories unless user wants new ones
        )

        new_blueprint_success = submit_action.call

        if new_blueprint_success
          puts '✅ Edit operation completed successfully!'.colorize(:green)
          puts '💡 The blueprint now has fresh embeddings for improved search'.colorize(:cyan)
          true
        else
          puts '❌ Failed to create new blueprint'.colorize(:red)
          puts '⚠️  Original blueprint has been deleted and cannot be restored'.colorize(:red)
          puts '💡 You may need to manually recreate the blueprint'.colorize(:yellow)
          false
        end
      end
    end
  end
end
