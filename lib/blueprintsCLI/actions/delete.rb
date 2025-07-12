# frozen_string_literal: true

module BlueprintsCLI
  module Actions
    # Handles the deletion of blueprints from the system with interactive confirmation.
    #
    # This action provides both direct deletion through ID specification and
    # interactive selection from available blueprints. It includes safety
    # mechanisms like confirmation dialogs and code previews to prevent
    # accidental deletions.
    #
    # @example Delete a blueprint by ID
    #   action = BlueprintsCLI::Actions::Delete.new(id: 123)
    #   action.call
    #
    # @example Interactive blueprint deletion
    #   action = BlueprintsCLI::Actions::Delete.new
    #   action.call # Will prompt for interactive selection
    class Delete < Sublayer::Actions::Base
      # Initializes a new Delete
      #
      # @param id [Integer, nil] The ID of the blueprint to delete (optional)
      # @param force [Boolean] Whether to skip confirmation prompts (default: false)
      def initialize(id: nil, force: false)
        @id = id
        @force = force
        @db = BlueprintsCLI::Wrappers::BlueprintDatabase.new
      end

      # Executes the blueprint deletion process
      #
      # When no ID is provided, initiates interactive selection. Shows
      # blueprint details and requests confirmation before deletion unless
      # force flag is true.
      #
      # @return [Boolean] true if deletion was successful, false otherwise
      #
      # @raise [StandardError] If there's an error during the deletion process
      #
      # @example Successful deletion
      #   action = BlueprintsCLI::Actions::Delete.new(id: 123)
      #   action.call # => true
      #
      # @example Failed deletion
      #   action = BlueprintsCLI::Actions::Delete.new(id: 999)
      #   action.call # => false (blueprint not found)
      def call
        # If no ID provided, show interactive selection
        if @id.nil?
          @id = select_blueprint_interactively
          return false unless @id
        end

        # Fetch the blueprint to delete
        blueprint = @db.get_blueprint(@id)
        unless blueprint
          BlueprintsCLI.logger.failure("Blueprint #{@id} not found")
          return false
        end

        # Show blueprint details and confirm deletion
        return false if !@force && !confirm_deletion?(blueprint)

        # Perform the deletion
        BlueprintsCLI.logger.step('Deleting blueprint...')

        if @db.delete_blueprint(@id)
          BlueprintsCLI.logger.success("Blueprint '#{blueprint[:name]}' (ID: #{@id}) deleted successfully")
          true
        else
          BlueprintsCLI.logger.failure('Failed to delete blueprint')
          false
        end
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error deleting blueprint: #{e.message}")
        BlueprintsCLI.logger.debug(e) if ENV['DEBUG']
        false
      end

      private

      # Presents an interactive menu to select a blueprint for deletion
      #
      # Displays a numbered list of available blueprints with their
      # basic information and allows the user to select one by number.
      #
      # @return [Integer, nil] The ID of the selected blueprint or nil if cancelled
      #
      # @example
      #   select_blueprint_interactively
      #   # Shows menu and returns selected blueprint ID or nil
      def select_blueprint_interactively
        puts '🔍 Loading blueprints for selection...'.colorize(:blue)

        blueprints = @db.list_blueprints(limit: 50)

        if blueprints.empty?
          puts '❌ No blueprints found'.colorize(:red)
          return nil
        end

        puts "\nSelect a blueprint to delete:"
        puts '=' * 60

        blueprints.each_with_index do |blueprint, index|
          categories = blueprint[:categories].map { |c| c[:title] }.join(', ')
          puts "#{index + 1}. #{blueprint[:name]} (ID: #{blueprint[:id]})"
          puts "   Description: #{blueprint[:description]}"
          puts "   Categories: #{categories}" unless categories.empty?
          puts "   Created: #{blueprint[:created_at]}"
          puts ''
        end

        print "Enter the number of the blueprint to delete (1-#{blueprints.length}), or 'q' to quit: "
        response = $stdin.gets.chomp

        if response.downcase == 'q'
          puts '❌ Operation cancelled'.colorize(:yellow)
          return nil
        end

        index = response.to_i - 1
        if index >= 0 && index < blueprints.length
          blueprints[index][:id]
        else
          puts '❌ Invalid selection'.colorize(:red)
          nil
        end
      end

      # Requests confirmation before deleting a blueprint
      #
      # Displays detailed information about the blueprint including a code preview
      # and warns about the irreversible nature of the deletion.
      #
      # @param blueprint [Hash] The blueprint to be deleted
      # @return [Boolean] true if deletion is confirmed, false otherwise
      #
      # @example
      #   blueprint = { id: 123, name: "Example", code: "puts 'hello'" }
      #   confirm_deletion?(blueprint)
      #   # Shows confirmation dialog and returns true/false based on user input
      def confirm_deletion?(blueprint)
        puts "\n#{'=' * 60}"
        puts '🗑️  Blueprint Deletion Confirmation'.colorize(:red)
        puts '=' * 60
        puts "ID: #{blueprint[:id]}"
        puts "Name: #{blueprint[:name]}"
        puts "Description: #{blueprint[:description]}"

        categories = blueprint[:categories].map { |c| c[:title] }.join(', ')
        puts "Categories: #{categories}" unless categories.empty?

        puts "Created: #{blueprint[:created_at]}"
        puts "Updated: #{blueprint[:updated_at]}"
        puts "Code length: #{blueprint[:code].length} characters"
        puts ''

        # Show first few lines of code as preview
        code_lines = blueprint[:code].lines
        puts 'Code preview (first 5 lines):'
        code_lines.first(5).each_with_index do |line, i|
          puts "  #{i + 1}: #{line.chomp}"
        end
        puts '  ...' if code_lines.length > 5
        puts ''

        puts '⚠️  WARNING: This action cannot be undone!'.colorize(:yellow)
        puts 'The blueprint and all its metadata will be permanently deleted.'.colorize(:yellow)
        puts ''

        print 'Are you sure you want to delete this blueprint? (y/N): '
        response = $stdin.gets.chomp.downcase

        if %w[y yes].include?(response)
          puts '✅ Deletion confirmed'.colorize(:green)
          true
        else
          puts '❌ Deletion cancelled'.colorize(:yellow)
          false
        end
      end
    end
  end
end
