# frozen_string_literal: true

require 'tty-box'
require 'tty-cursor'

module BlueprintsCLI
  module Actions
    ##
    # Action class for listing and interacting with blueprints in the system.
    #
    # This class provides functionality to fetch, display, and interact with blueprints
    # from the database. It supports multiple display formats and an interactive
    # browsing mode for enhanced user experience.
    #
    # @example Basic usage (non-interactive table format)
    #   BlueprintsCLI::Actions::List.new.call
    #
    # @example Interactive mode with summary format
    #   BlueprintsCLI::Actions::List.new(
    #     format: :summary,
    #     interactive: true
    #   ).call
    class List < Sublayer::Actions::Base
      ##
      # Initializes a new List instance.
      #
      # @param format [Symbol] The display format for blueprints. Can be:
      #   :table (default) - displays blueprints in a formatted table
      #   :summary - shows a summary of blueprints with category statistics
      #   :json - outputs blueprints as JSON
      # @param interactive [Boolean] Whether to enable interactive mode with a browser interface
      # @param limit [Integer] Maximum number of blueprints to fetch (default: 50)
      # @return [List] a new instance of List
      def initialize(format: :table, interactive: false, limit: 50)
        @format = format
        @interactive = interactive
        @limit = limit
        @db = BlueprintsCLI::BlueprintDatabase.new
      end

      ##
      # Executes the blueprint listing action.
      #
      # Fetches blueprints from the database and displays them according to the specified format.
      # In interactive mode, provides a browser interface for navigating and managing blueprints.
      #
      # @return [Boolean] true if the operation succeeded, false if an error occurred
      #
      # @example Basic execution
      #   action = BlueprintsCLI::Actions::List.new
      #   action.call #=> true
      def call
        BlueprintsCLI.logger.step('Fetching blueprints...')

        blueprints = @db.list_blueprints(limit: @limit)

        if blueprints.empty?
          BlueprintsCLI.logger.warn('No blueprints found')
          return true
        end

        BlueprintsCLI.logger.success("Found #{blueprints.length} blueprints")

        if @interactive && tty_prompt_available?
          interactive_blueprint_browser(blueprints)
        else
          display_blueprints(blueprints)
        end

        true
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error listing blueprints: #{e.message}")
        BlueprintsCLI.logger.debug(e) if ENV['DEBUG']
        false
      end

      private

      ##
      # Displays blueprints according to the specified format.
      #
      # @param blueprints [Array<Hash>] The collection of blueprints to display
      # @return [void]
      def display_blueprints(blueprints)
        case @format
        when :table
          display_table(blueprints)
        when :summary
          display_summary(blueprints)
        when :json
          puts JSON.pretty_generate(blueprints)
        else
          display_table(blueprints)
        end
      end

      ##
      # Displays blueprints in a formatted table.
      #
      # @param blueprints [Array<Hash>] The collection of blueprints to display
      # @return [void]
      #
      # @example Table format output
      #   ========================================================================================================================
      #   ID    Name                           Description                                          Categories
      #   ========================================================================================================================
      #   1     Sample Blueprint               This is a sample blueprint description               Category1, Category2
      #   2     Another Blueprint              Description of another blueprint                       Category3
      #   ========================================================================================================================
      def display_table(blueprints)
        # Display header using TTY::Box
        header_box = TTY::Box.frame(
          "📚 Blueprint Collection",
          width: 120,
          align: :center,
          style: { border: { fg: :blue } }
        )
        puts "\n#{header_box}"

        printf "%-5s %-30s %-50s %-25s\n", 'ID', 'Name', 'Description', 'Categories'
        puts '=' * 120

        blueprints.each do |blueprint|
          name = truncate_text(blueprint[:name] || 'Untitled', 28)
          description = truncate_text(blueprint[:description] || 'No description', 48)
          categories = get_category_text(blueprint[:categories])

          printf "%-5s %-30s %-50s %-25s\n",
                 blueprint[:id],
                 name,
                 description,
                 categories
        end
        puts '=' * 120
        puts ''
      end

      ##
      # Displays a summary of the blueprint collection with statistics.
      #
      # Shows total count of blueprints, top categories, and most recent blueprints.
      #
      # @param blueprints [Array<Hash>] The collection of blueprints to summarize
      # @return [void]
      #
      # @example Summary format output
      #   📊 Blueprint Collection Summary
      #   ===================================================
      #   Total blueprints: 42
      #
      #   Top categories:
      #     Web Development: 12 blueprints
      #     Data Processing: 8 blueprints
      #     Utilities: 5 blueprints
      #
      #   Most recent blueprints:
      #     42: Latest Blueprint
      #     41: Previous Blueprint
      def display_summary(blueprints)
        puts "\n📊 Blueprint Collection Summary".colorize(:blue)
        puts '=' * 50
        puts "Total blueprints: #{blueprints.length}"

        # Category analysis
        all_categories = blueprints.flat_map { |b| b[:categories].map { |c| c[:name] } }
        category_counts = all_categories.each_with_object(Hash.new(0)) do |cat, hash|
          hash[cat] += 1
        end

        if category_counts.any?
          puts "\nTop categories:"
          category_counts.sort_by { |_, count| -count }.first(5).each do |category, count|
            puts "  #{category}: #{count} blueprints"
          end
        end

        # Recent blueprints
        puts "\nMost recent blueprints:"
        blueprints.first(5).each do |blueprint|
          puts "  #{blueprint[:id]}: #{blueprint[:name]}"
        end
        puts ''
      end

      ##
      # Launches an interactive browser for navigating blueprints.
      #
      # Provides a menu-driven interface for selecting, searching, and managing blueprints.
      #
      # @param blueprints [Array<Hash>] The collection of blueprints to browse
      # @return [void]
      def interactive_blueprint_browser(blueprints)
        return unless tty_prompt_available?

        prompt = TTY::Prompt.new
        first_iteration = true

        loop do
          # Only clear screen on first iteration, add spacing on subsequent ones
          if first_iteration
            clear_screen_smart
            first_iteration = false
          else
            add_spacing(2)
          end
          
          display_browser_header(blueprints)
          choices = build_browser_choices(blueprints)
          selected = prompt.select('Select a blueprint or action:', choices, per_page: 15)

          break if handle_browser_selection(selected, blueprints, prompt)
        end
      end

      ##
      # Displays the browser header with blueprint count.
      #
      # @param blueprints [Array<Hash>] The collection of blueprints being browsed
      # @return [void]
      def display_browser_header(blueprints)
        puts '=' * 80
        puts '📚 Blueprint Browser'.colorize(:blue)
        puts "Found #{blueprints.length} blueprints"
        puts '=' * 80
      end

      ##
      # Builds the choices array for the blueprint browser prompt.
      #
      # Combines blueprint choices with action options.
      #
      # @param blueprints [Array<Hash>] The collection of blueprints to browse
      # @return [Array<Hash>] Complete choices array for the prompt
      def build_browser_choices(blueprints)
        choices = prepare_blueprint_choices(blueprints)

        # Add action options
        choices << { name: '🔍 Search blueprints'.colorize(:blue), value: :search }
        choices << { name: '📊 Show summary'.colorize(:yellow), value: :summary }
        choices << { name: '➕ Submit new blueprint'.colorize(:green), value: :submit }
        choices << { name: '🚪 Exit'.colorize(:red), value: :exit }

        choices
      end

      ##
      # Handles the user's selection from the browser menu.
      #
      # Routes to appropriate handlers based on the selection type.
      #
      # @param selected [Hash, Symbol] The user's selection from the prompt
      # @param blueprints [Array<Hash>] The collection of blueprints (passed by reference for updates)
      # @param prompt [TTY::Prompt] The prompt instance for user interaction
      # @return [Boolean] Returns true if the browser should exit, false to continue
      def handle_browser_selection(selected, blueprints, prompt)
        case selected
        when Hash
          # A blueprint was selected
          handle_selected_blueprint(selected, prompt)
          false
        when :search
          handle_search_action(prompt)
          false
        when :summary
          display_summary(blueprints)
          prompt.keypress('Press any key to continue...')
          false
        when :submit
          submission_success = handle_submit_action(prompt)
          # Refresh blueprints if submission was successful
          if submission_success
            blueprints.replace(refresh_blueprint_list)
          end
          false
        when :exit
          puts '👋 Goodbye!'.colorize(:green)
          true
        else
          false
        end
      end

      ##
      # Refreshes the blueprint list from the database.
      #
      # @return [Array<Hash>] Updated collection of blueprints
      def refresh_blueprint_list
        @db.list_blueprints(limit: @limit)
      end

      ##
      # Prepares blueprint choices for the interactive prompt.
      #
      # Formats blueprint information for display in the selection menu.
      #
      # @param blueprints [Array<Hash>] The collection of blueprints to format
      # @return [Array<Hash>] Formatted choices for the prompt
      def prepare_blueprint_choices(blueprints)
        blueprints.map do |blueprint|
          name = truncate_text(blueprint[:name] || 'Untitled', 40)
          description = truncate_text(blueprint[:description] || 'No description', 50)
          categories = get_category_text(blueprint[:categories], 20)

          display_text = "#{name.ljust(42)} | #{description.ljust(52)} | #{categories}"

          {
            name: display_text,
            value: blueprint
          }
        end
      end

      ##
      # Handles actions for a selected blueprint in interactive mode.
      #
      # Provides options to view, edit, export, analyze, or copy the blueprint ID.
      #
      # @param blueprint [Hash] The selected blueprint
      # @param prompt [TTY::Prompt] The prompt instance for user interaction
      # @return [void]
      def handle_selected_blueprint(blueprint, prompt)
        actions = [
          { name: '👁️  View details', value: :view },
          { name: '✏️  Edit blueprint', value: :edit },
          { name: '💾 Export code', value: :export },
          { name: '🔍 View with AI analysis', value: :analyze },
          { name: '📋 Copy ID', value: :copy_id },
          { name: '↩️  Back to list', value: :back }
        ]

        action = prompt.select("What would you like to do with '#{blueprint[:name]}'?", actions)

        case action
        when :view
          BlueprintsCLI::Actions::View.new(
            id: blueprint[:id],
            format: :detailed
          ).call
          prompt.keypress('Press any key to continue...')
        when :edit
          BlueprintsCLI::Actions::Edit.new(
            id: blueprint[:id]
          ).call
          prompt.keypress('Press any key to continue...')
        when :export
          filename = prompt.ask('💾 Export filename:', default: generate_export_filename(blueprint))
          BlueprintsCLI::Actions::Export.new(
            id: blueprint[:id],
            output_path: filename
          ).call
          prompt.keypress('Press any key to continue...')
        when :analyze
          BlueprintsCLI::Actions::View.new(
            id: blueprint[:id],
            format: :detailed,
            with_suggestions: true
          ).call
          prompt.keypress('Press any key to continue...')
        when :copy_id
          puts "📋 Blueprint ID: #{blueprint[:id]}".colorize(:green)
          # Try to copy to clipboard if available
          copy_to_clipboard(blueprint[:id].to_s)
          prompt.keypress('Press any key to continue...')
        when :back
          # Return to blueprint list
          nil
        end
      end

      ##
      # Handles the search action in interactive mode.
      #
      # Prompts the user for a search query and performs the search.
      #
      # @param prompt [TTY::Prompt] The prompt instance for user interaction
      # @return [void]
      def handle_search_action(prompt)
        query = prompt.ask('🔍 Enter search query:', required: true)

        BlueprintsCLI::Actions::Search.new(
          query: query,
          limit: 10
        ).call

        prompt.keypress('Press any key to continue...')
      end

      ##
      # Handles the blueprint submission action in interactive mode.
      #
      # Provides options to submit a blueprint from a file or text input.
      #
      # @param prompt [TTY::Prompt] The prompt instance for user interaction
      # @return [void]
      def handle_submit_action(prompt)
        submit_choice = prompt.select('Submit from:', [
                                        { name: '📁 File', value: :file },
                                        { name: '✏️  Text input', value: :text }
                                      ])

        success = false
        if submit_choice == :file
          file_path = prompt.ask('📁 Enter file path:')
          if file_path && File.exist?(file_path)
            code = File.read(file_path)
            success = BlueprintsCLI::Actions::Submit.new(code: code).call
          else
            puts "❌ File not found: #{file_path}".colorize(:red)
          end
        else
          code = prompt.multiline('✏️  Enter code (Ctrl+D to finish):')
          if code && !code.join("\n").strip.empty?
            success = BlueprintsCLI::Actions::Submit.new(code: code.join("\n")).call
          end
        end

        prompt.keypress('Press any key to continue...')
        
        # Return success status to indicate if blueprints need to be refreshed
        success
      end

      ##
      # Generates a formatted string of category names from a blueprint's categories.
      #
      # @param categories [Array<Hash>, nil] The categories associated with a blueprint
      # @param max_length [Integer] Maximum length for the resulting string (default: 23)
      # @return [String] Formatted category text
      #
      # @example
      #   get_category_text([{title: "Web"}, {title: "Ruby"}]) #=> "Web, Ruby"
      def get_category_text(categories, max_length = 23)
        return 'No categories' if categories.nil? || categories.empty?

        category_names = categories.map { |cat| cat[:title] }
        text = category_names.join(', ')
        truncate_text(text, max_length)
      end

      ##
      # Generates a filename for exporting a blueprint.
      #
      # Creates a filename based on the blueprint's name and ID, with an appropriate extension.
      #
      # @param blueprint [Hash] The blueprint to generate a filename for
      # @return [String] Generated filename
      #
      # @example
      #   generate_export_filename({name: "Sample", id: 42, code: "class Sample..."})
      #   #=> "sample_42.rb"
      def generate_export_filename(blueprint)
        base_name = (blueprint[:name] || 'blueprint').gsub(/[^a-zA-Z0-9_-]/, '_').downcase
        extension = detect_file_extension(blueprint[:code] || '')
        "#{base_name}_#{blueprint[:id]}#{extension}"
      end

      ##
      # Detects the appropriate file extension based on code content.
      #
      # @param code [String] The code content to analyze
      # @return [String] Detected file extension
      #
      # @example
      #   detect_file_extension("class Sample...") #=> ".rb"
      #   detect_file_extension("function sample()") #=> ".js"
      def detect_file_extension(code)
        case code
        when /class\s+\w+.*<.*ApplicationRecord/m, /def\s+\w+.*end/m
          '.rb'
        when /function\s+\w+\s*\(/m, /const\s+\w+\s*=/m
          '.js'
        when /def\s+\w+\s*\(/m, /import\s+\w+/m
          '.py'
        when /#include\s*<.*>/m, /int\s+main\s*\(/m
          '.c'
        else
          '.txt'
        end
      end

      ##
      # Attempts to copy text to the system clipboard.
      #
      # Tries multiple clipboard commands for cross-platform compatibility.
      #
      # @param text [String] The text to copy to clipboard
      # @return [Boolean] true if copying succeeded, false otherwise
      def copy_to_clipboard(text)
        # Try different clipboard commands
        commands = [
          "echo '#{text}' | pbcopy", # macOS
          "echo '#{text}' | xclip -selection clipboard", # Linux with xclip
          "echo '#{text}' | xsel -i -b" # Linux with xsel
        ]

        commands.each do |cmd|
          if system(cmd + ' 2>/dev/null')
            puts '📋 Copied to clipboard!'.colorize(:green)
            return true
          end
        end

        puts '⚠️  Could not copy to clipboard (clipboard tool not available)'.colorize(:yellow)
        false
      end

      ##
      # Truncates text to a specified length, adding ellipsis if needed.
      #
      # @param text [String] The text to truncate
      # @param length [Integer] Maximum length of the resulting string
      # @return [String] Truncated text
      #
      # @example
      #   truncate_text("This is a long text", 10) #=> "This is a..."
      def truncate_text(text, length)
        return text if text.length <= length

        text[0..length - 4] + '...'
      end

      ##
      # Checks if TTY prompt is available for interactive mode.
      #
      # @return [Boolean] true if TTY::Prompt is defined and available
      def tty_prompt_available?
        defined?(TTY::Prompt)
      end

      ##
      # Smart screen clearing that only clears when necessary
      #
      # @return [void]
      def clear_screen_smart
        print TTY::Cursor.clear_screen_down if defined?(TTY::Cursor)
      end

      ##
      # Adds spacing without clearing the screen
      #
      # @param lines [Integer] number of lines to add (default: 2)
      # @return [void]
      def add_spacing(lines = 2)
        puts "\n" * lines
      end
    end
  end
end
