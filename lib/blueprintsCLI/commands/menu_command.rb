# frozen_string_literal: true

require 'tty-box'
require 'tty-cursor'
require 'tty-pager'

module BlueprintsCLI
  module Commands
    # MenuCommand provides an interactive command menu system for BlueprintsCLI.
    # It displays available commands, handles user input, and executes selected commands.
    # This class serves as the main interactive interface when no specific command is provided.
    #
    # @example Basic Usage
    #   BlueprintsCLI::Commands::MenuCommand.new.start
    #
    # @example With Debugging
    #   BlueprintsCLI::Commands::MenuCommand.new(debug: true).start
    class MenuCommand
      # Initializes a new MenuCommand instance.
      #
      # @param debug [Boolean] whether to enable debug logging
      # @option debug [Boolean] :debug (false) enables debug output if true
      def initialize(debug: false)
        @prompt = TTY::Prompt.new(input: $stdin, output: $stdout, enable_color: true,
                                  interrupt: :exit)
        @commands = available_commands
        @debug = debug
      end

      # Starts the interactive menu loop.
      # Displays the main menu, processes user selections, and executes the chosen commands.
      # Continues running until the user selects the exit option.
      #
      # @return [void]
      def start
        # Check if we can use interactive mode
        if interactive_mode_available?
          start_interactive_mode
        else
          start_fallback_mode
        end
      end

      # Check if interactive TTY mode is available
      #
      # @return [Boolean] true if interactive mode can work
      def interactive_mode_available?
        $stdin.tty? && $stdout.tty? && ENV.fetch('TERM', nil) && !ENV['CI']
      rescue StandardError
        false
      end

      # Start the normal interactive mode
      #
      # @return [void]
      def start_interactive_mode
        # Clear screen only once at the start
        clear_screen_smart

        loop do
          choice = main_menu

          # Debug logging
          debug_log("Choice selected: #{choice.inspect} (#{choice.class})")

          case choice
          when :exit
            puts '👋 Goodbye!'.colorize(:green)
            break
          else
            # All command names are strings, so handle them directly
            debug_log("Handling command: #{choice}")
            result = handle_command(choice)
            debug_log("Command result: #{result}")
            # If command handler returns :exit, break the loop
            break if result == :exit
          end
        end
      end

      # Fallback mode for non-interactive environments
      #
      # @return [void]
      def start_fallback_mode
        puts '🚀 BlueprintsCLI - Non-interactive mode'.colorize(:cyan)
        puts 'Available commands:'.colorize(:yellow)

        @commands.each_with_index do |cmd, index|
          puts "  #{index + 1}. #{cmd[:name]} - #{cmd[:description]}"
        end
        puts "  #{@commands.length + 1}. logs - View application logs"
        puts "  #{@commands.length + 2}. exit - Exit the application"

        print "\nEnter command number or name: ".colorize(:cyan)
        $stdout.flush
        input = $stdin.gets&.chomp

        if input.nil? || input.empty?
          puts 'No input received. Exiting.'.colorize(:yellow)
          return
        end

        # Handle numeric input
        if input.match?(/^\d+$/)
          choice_index = input.to_i - 1
          if choice_index >= 0 && choice_index < @commands.length
            choice = @commands[choice_index][:name]
          elsif choice_index == @commands.length
            choice = 'logs'
          elsif choice_index == @commands.length + 1
            choice = :exit
          else
            puts "Invalid selection: #{input}".colorize(:red)
            return
          end
        else
          # Handle text input
          choice = input.downcase
          choice = :exit if choice == 'exit'
        end

        case choice
        when :exit
          puts '👋 Goodbye!'.colorize(:green)
        else
          result = handle_command(choice)
          puts "Command completed with result: #{result}".colorize(:green) if result != :continue
        end
      end

      private

      # Logs debug messages when debug mode is enabled.
      #
      # @param message [String] the debug message to log
      # @return [void]
      def debug_log(message)
        puts "🔍 DEBUG: #{message}".colorize(:magenta) if @debug
      end

      # Smart screen clearing that only clears when necessary
      #
      # @return [void]
      def clear_screen_smart
        print TTY::Cursor.clear_screen_down
      end

      # Adds spacing without clearing the screen
      #
      # @param lines [Integer] number of lines to add (default: 2)
      # @return [void]
      def add_spacing(lines = 2)
        puts "\n" * lines
      end

      # Clears only the current line and moves cursor to beginning
      #
      # @return [void]
      def clear_current_line
        print TTY::Cursor.clear_line if defined?(TTY::Cursor)
        print "\r"
      end

      # Retrieves the list of available commands from the BlueprintsCLI::Commands module.
      # Excludes base classes and the MenuCommand itself.
      #
      # @return [Array<Hash>] array of command hashes with name, description, and class
      def available_commands
        excluded_commands = %i[BaseCommand MenuCommand]
        valid_commands = BlueprintsCLI::Commands.constants.reject do |command_class|
          excluded_commands.include?(command_class)
        end

        valid_commands.map do |command_class|
          command = BlueprintsCLI::Commands.const_get(command_class)
          {
            name: command.command_name,
            description: command.description,
            class: command
          }
        end
      end

      # Displays the main menu and captures user selection.
      #
      # @return [Symbol, String] the selected command name or :exit symbol
      def main_menu
        debug_log("Building main menu with commands: #{@commands.map { |cmd| cmd[:name] }}")

        # Add some spacing between iterations instead of clearing
        add_spacing(2)

        # Display the application banner using TTY::Box
        banner = TTY::Box.frame(
          "🚀 BlueprintsCLI 🚀\n\nYour Blueprint Management Hub",
          padding: 1,
          align: :center,
          title: { top_left: 'v1.0' },
          style: { border: { fg: :cyan } }
        )
        puts banner

        begin
          result = @prompt.select('Select a command:'.colorize(:cyan)) do |menu|
            @commands.each do |cmd|
              debug_log("Adding menu choice: '#{cmd[:name].capitalize} - #{cmd[:description]}' -> #{cmd[:name].inspect}")
              menu.choice "#{cmd[:name].capitalize} - #{cmd[:description]}", cmd[:name]
            end
            menu.choice '📋 View Logs', 'logs'
            menu.choice 'Exit', :exit
          end

          debug_log("Menu selection returned: #{result.inspect}")
          result
        rescue TTY::Reader::InputInterrupt, Interrupt
          debug_log('User interrupted menu selection')
          :exit
        rescue StandardError => e
          debug_log("Error in menu selection: #{e.message}")
          puts "❌ Menu error: #{e.message}".colorize(:red)
          :exit
        end
      end

      # Handles the execution of a selected command.
      #
      # @param command_name [String] the name of the command to execute
      # @return [Symbol] :continue to keep the menu running, or :exit to stop
      def handle_command(command_name)
        debug_log("Looking for command: #{command_name.inspect}")
        debug_log("Available commands: #{@commands.map { |cmd| cmd[:name] }}")

        # Special handling for logs command which is not in the commands array
        if command_name == 'logs'
          debug_log('Executing logs command (special menu command)')
          return handle_logs_command
        end

        command_info = @commands.find { |cmd| cmd[:name] == command_name }
        debug_log("Command found: #{command_info ? 'YES' : 'NO'}")

        return :continue unless command_info

        debug_log("Executing command handler for: #{command_name}")
        case command_name
        when 'blueprint'
          handle_blueprint_command
        when 'config'
          handle_config_command
        when 'docs'
          handle_docs_command
        when 'setup'
          handle_setup_command
        when 'logs'
          handle_logs_command
        else
          puts "❌ Unknown command: #{command_name}".colorize(:red)
          :continue
        end
      end

      # Handles the blueprint command submenu and operations.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_blueprint_command
        debug_log('Entering handle_blueprint_command')
        subcommand = @prompt.select('📋 Blueprint - Choose operation:'.colorize(:blue)) do |menu|
          menu.choice 'Submit new blueprint', 'submit'
          menu.choice 'List all blueprints', 'list'
          menu.choice 'Browse blueprints interactively', 'browse'
          menu.choice 'View specific blueprint', 'view'
          menu.choice 'Edit blueprint', 'edit'
          menu.choice 'Delete blueprint', 'delete'
          menu.choice 'Search blueprints', 'search'
          menu.choice 'Export blueprint', 'export'
          menu.choice '🤖 Generate code from description', 'generate'
          menu.choice 'Configuration', 'config'
          menu.choice 'Back to main menu', :back
        end

        return :continue if subcommand == :back

        begin
          case subcommand
          when 'submit'
            handle_blueprint_submit
          when 'list'
            handle_blueprint_list
          when 'browse'
            execute_blueprint_command('browse')
          when 'view'
            handle_blueprint_view
          when 'edit'
            handle_blueprint_edit
          when 'delete'
            handle_blueprint_delete
          when 'search'
            handle_blueprint_search
          when 'export'
            handle_blueprint_export
          when 'generate'
            handle_blueprint_generate
          when 'config'
            handle_blueprint_config
          end
        rescue StandardError => e
          BlueprintsCLI.logger.failure("Error executing blueprint command: #{e.message}")
        end

        :continue
      end

      # Executes a blueprint command with the given subcommand and arguments.
      #
      # @param subcommand [String] the blueprint subcommand to execute
      # @param args [Array] additional arguments for the command
      # @return [void]
      def execute_blueprint_command(subcommand, *args)
        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new({})
        blueprint_command.execute(subcommand, *args)
      end

      # Handles the blueprint submission process.
      # Prompts the user for input and options, then executes the submit command.
      #
      # @return [void]
      def handle_blueprint_submit
        input = @prompt.ask('📁 Enter file path or code string:')
        return if input.nil? || input.empty?

        auto_describe = @prompt.yes?('🤖 Auto-generate description?')
        auto_categorize = @prompt.yes?('🏷️ Auto-categorize?')

        args = [input]
        options = {}
        options['auto_describe'] = false unless auto_describe
        options['auto_categorize'] = false unless auto_categorize

        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('submit', *args)
      end

      # Handles listing blueprints with various format options.
      #
      # @return [void]
      def handle_blueprint_list
        format = @prompt.select('📊 Choose format:') do |menu|
          menu.choice 'Table', 'table'
          menu.choice 'Summary', 'summary'
          menu.choice 'JSON', 'json'
        end

        interactive = @prompt.yes?('🔄 Interactive mode?')

        options = { 'format' => format }
        options['interactive'] = true if interactive

        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('list')
      end

      # Handles viewing a specific blueprint with various format options.
      #
      # @return [void]
      def handle_blueprint_view
        id = @prompt.ask('🔍 Enter blueprint ID:')
        return if id.nil? || id.empty?

        format = @prompt.select('📊 Choose format:') do |menu|
          menu.choice 'Detailed', 'detailed'
          menu.choice 'Summary', 'summary'
          menu.choice 'JSON', 'json'
        end

        analyze = @prompt.yes?('🧠 Include AI analysis?')

        options = { 'format' => format }
        options['analyze'] = true if analyze

        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('view', id)
      end

      # Handles editing a blueprint.
      #
      # @return [void]
      def handle_blueprint_edit
        id = @prompt.ask('✏️ Enter blueprint ID to edit:')
        return if id.nil? || id.empty?

        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new({})
        blueprint_command.execute('edit', id)
      end

      # Handles deleting a blueprint with options for ID input or interactive selection.
      #
      # @return [void]
      def handle_blueprint_delete
        choice = @prompt.select('🗑️ How would you like to select the blueprint to delete?') do |menu|
          menu.choice 'Enter blueprint ID', 'id'
          menu.choice 'Select from list', 'interactive'
        end

        case choice
        when 'id'
          id = @prompt.ask('🗑️ Enter blueprint ID to delete:')
          return if id.nil? || id.empty?

          force = @prompt.yes?('⚠️ Skip confirmation? (Use with caution)')

          args = [id]
          args << '--force' if force

          blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new({})
          blueprint_command.execute('delete', *args)
        when 'interactive'
          blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new({})
          blueprint_command.execute('delete')
        end
      end

      # Handles searching blueprints with query and limit options.
      #
      # @return [void]
      def handle_blueprint_search
        query = @prompt.ask('🔍 Enter search query:')
        return if query.nil? || query.empty?

        limit = @prompt.ask('📊 Number of results (default 10):', default: '10')

        options = { 'limit' => limit.to_i }
        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('search', query)
      end

      # Handles exporting a blueprint with optional output path.
      #
      # @return [void]
      def handle_blueprint_export
        id = @prompt.ask('📤 Enter blueprint ID to export:')
        return if id.nil? || id.empty?

        output_path = @prompt.ask('💾 Output file path (optional):')

        args = [id]
        args << output_path unless output_path.nil? || output_path.empty?

        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new({})
        blueprint_command.execute('export', *args)
      end

      # Handles code generation from natural language description.
      #
      # @return [void]
      def handle_blueprint_generate
        description = @prompt.ask('🤖 Describe what you want to generate:')
        return if description.nil? || description.empty?

        output_dir = @prompt.ask('📁 Output directory:', default: './generated')
        limit = @prompt.ask('🔢 Number of blueprints to use as context:', default: '5').to_i
        force = @prompt.yes?('⚡ Overwrite existing files?')

        options = {
          'output_dir' => output_dir,
          'limit' => limit,
          'force' => force
        }

        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('generate', description)
      end

      # Handles blueprint configuration options.
      #
      # @return [void]
      def handle_blueprint_config
        subcommand = @prompt.select('⚙️ Configuration:') do |menu|
          menu.choice 'Show current config', 'show'
          menu.choice 'Setup configuration', 'setup'
        end

        blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new({})
        blueprint_command.execute('config', subcommand)
      end

      # Handles configuration commands with various sub-options.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_config_command
        debug_log('Entering handle_config_command')

        subcommand = @prompt.select('⚙️ Configuration - Choose operation:'.colorize(:blue)) do |menu|
          menu.choice '🔧 Setup configuration', 'setup'
          menu.choice '📋 Show current config', 'show'
          menu.choice '✏️ Edit configuration', 'edit'
          menu.choice '🔍 Validate configuration', 'validate'
          menu.choice '🔄 Reset configuration', 'reset'
          menu.choice '❓ Help', 'help'
          menu.choice 'Back to main menu', :back
        end

        return :continue if subcommand == :back

        begin
          config_command = BlueprintsCLI::Commands::ConfigCommand.new({})
          config_command.execute(subcommand)
        rescue StandardError => e
          BlueprintsCLI.logger.failure("Error executing config command: #{e.message}")
        end

        :continue
      end

      # Handles the docs command submenu and operations.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_docs_command
        debug_log('Entering handle_docs_command')

        subcommand = @prompt.select('📖 Documentation - Choose operation:'.colorize(:blue)) do |menu|
          menu.choice '🏗️ Generate YARD docs for file', 'generate'
          menu.choice '❓ Help', 'help'
          menu.choice 'Back to main menu', :back
        end

        return :continue if subcommand == :back

        case subcommand
        when 'generate'
          file_path = @prompt.ask('Enter the Ruby file path to document:', default: './')

          begin
            docs_command = BlueprintsCLI::Commands::DocsCommand.new({})
            docs_command.execute('generate', file_path)
          rescue StandardError => e
            BlueprintsCLI.logger.failure("Error executing docs command: #{e.message}")
          end
        when 'help'
          begin
            docs_command = BlueprintsCLI::Commands::DocsCommand.new({})
            docs_command.execute('help')
          rescue StandardError => e
            BlueprintsCLI.logger.failure("Error executing docs help: #{e.message}")
          end
        end

        :continue
      end

      # Handles the setup command submenu and operations.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_setup_command
        debug_log('Entering handle_setup_command')

        subcommand = @prompt.select('🔧 Setup - Choose operation:'.colorize(:blue)) do |menu|
          menu.choice '🚀 Run complete setup wizard', 'wizard'
          menu.choice '🤖 Setup AI providers only', 'providers'
          menu.choice '🗄️ Setup database only', 'database'
          menu.choice '📊 Setup AI models only', 'models'
          menu.choice '✅ Verify current setup', 'verify'
          menu.choice '❓ Help', 'help'
          menu.choice 'Back to main menu', :back
        end

        return :continue if subcommand == :back

        begin
          setup_command = BlueprintsCLI::Commands::SetupCommand.new({})
          setup_command.execute(subcommand)
        rescue StandardError => e
          BlueprintsCLI.logger.failure("Error executing setup command: #{e.message}")
        end

        :continue
      end

      # Handles the logs command using tty-pager to display log files.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_logs_command
        debug_log('Entering handle_logs_command')

        begin
          # Get the default log path from the logger
          log_path = BlueprintsCLI::Logger.send(:default_log_path)

          unless File.exist?(log_path)
            puts "📋 No log file found at #{log_path}".colorize(:yellow)
            return :continue
          end

          # Display log file info
          file_size = File.size(log_path)
          file_mtime = File.mtime(log_path)
          puts "\n📋 Log File: #{log_path}".colorize(:cyan)
          puts "📊 Size: #{format_file_size(file_size)}".colorize(:blue)
          puts "📅 Last Modified: #{file_mtime.strftime('%Y-%m-%d %H:%M:%S')}".colorize(:blue)
          puts

          # Use tty-pager to display the log file
          TTY::Pager.page(path: log_path)
        rescue StandardError => e
          BlueprintsCLI.logger.failure("Error viewing logs: #{e.message}")
          puts "❌ Error viewing logs: #{e.message}".colorize(:red)
        end

        :continue
      end

      # Format file size in human-readable format
      #
      # @param size [Integer] file size in bytes
      # @return [String] formatted file size
      def format_file_size(size)
        units = %w[B KB MB GB TB]
        unit_index = 0
        size_float = size.to_f

        while size_float >= 1024 && unit_index < units.length - 1
          size_float /= 1024
          unit_index += 1
        end

        if unit_index == 0
          "#{size_float.to_i} #{units[unit_index]}"
        else
          "#{'%.1f' % size_float} #{units[unit_index]}"
        end
      end
    end
  end
end
