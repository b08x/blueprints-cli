# frozen_string_literal: true

module ComputerTools
  module Commands
    # MenuCommand provides an interactive command menu system for ComputerTools.
    # It displays available commands, handles user input, and executes selected commands.
    # This class serves as the main interactive interface when no specific command is provided.
    #
    # @example Basic Usage
    #   ComputerTools::Commands::MenuCommand.new.start
    #
    # @example With Debugging
    #   ComputerTools::Commands::MenuCommand.new(debug: true).start
    class MenuCommand
      # Initializes a new MenuCommand instance.
      #
      # @param debug [Boolean] whether to enable debug logging
      # @option debug [Boolean] :debug (false) enables debug output if true
      def initialize(debug: false)
        @prompt = TTY::Prompt.new
        @commands = available_commands
        @debug = debug
      end

      # Starts the interactive menu loop.
      # Displays the main menu, processes user selections, and executes the chosen commands.
      # Continues running until the user selects the exit option.
      #
      # @return [void]
      def start
        loop do
          choice = main_menu

          # Debug logging
          debug_log("Choice selected: #{choice.inspect} (#{choice.class})")

          case choice
          when :exit
            puts "👋 Goodbye!".colorize(:green)
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

      private

      # Logs debug messages when debug mode is enabled.
      #
      # @param message [String] the debug message to log
      # @return [void]
      def debug_log(message)
        puts "🔍 DEBUG: #{message}".colorize(:magenta) if @debug
      end

      # Retrieves the list of available commands from the ComputerTools::Commands module.
      # Excludes base classes and the MenuCommand itself.
      #
      # @return [Array<Hash>] array of command hashes with name, description, and class
      def available_commands
        excluded_commands = %i[BaseCommand MenuCommand]
        valid_commands = ComputerTools::Commands.constants.reject do |command_class|
          excluded_commands.include?(command_class)
        end

        valid_commands.map do |command_class|
          command = ComputerTools::Commands.const_get(command_class)
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

        result = @prompt.select("🚀 ComputerTools - Select a command:".colorize(:cyan)) do |menu|
          @commands.each do |cmd|
            debug_log("Adding menu choice: '#{cmd[:name].capitalize} - #{cmd[:description]}' -> #{cmd[:name].inspect}")
            menu.choice "#{cmd[:name].capitalize} - #{cmd[:description]}", cmd[:name]
          end
          menu.choice "Exit", :exit
        end

        debug_log("Menu selection returned: #{result.inspect}")
        result
      end

      # Handles the execution of a selected command.
      #
      # @param command_name [String] the name of the command to execute
      # @return [Symbol] :continue to keep the menu running, or :exit to stop
      def handle_command(command_name)
        debug_log("Looking for command: #{command_name.inspect}")
        debug_log("Available commands: #{@commands.map { |cmd| cmd[:name] }}")

        command_info = @commands.find { |cmd| cmd[:name] == command_name }
        debug_log("Command found: #{command_info ? 'YES' : 'NO'}")

        return :continue unless command_info

        debug_log("Executing command handler for: #{command_name}")
        case command_name
        when 'blueprint'
          handle_blueprint_command
        when 'deepgram'
          handle_deepgram_command
        when 'example'
          handle_example_command
        when 'latestchanges'
          handle_latest_changes_command
        when 'config'
          handle_config_command
        else
          puts "❌ Unknown command: #{command_name}".colorize(:red)
          :continue
        end
      end

      # Handles the blueprint command submenu and operations.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_blueprint_command
        debug_log("Entering handle_blueprint_command")
        subcommand = @prompt.select("📋 Blueprint - Choose operation:".colorize(:blue)) do |menu|
          menu.choice "Submit new blueprint", "submit"
          menu.choice "List all blueprints", "list"
          menu.choice "Browse blueprints interactively", "browse"
          menu.choice "View specific blueprint", "view"
          menu.choice "Edit blueprint", "edit"
          menu.choice "Delete blueprint", "delete"
          menu.choice "Search blueprints", "search"
          menu.choice "Export blueprint", "export"
          menu.choice "Configuration", "config"
          menu.choice "Back to main menu", :back
        end

        return :continue if subcommand == :back

        begin
          case subcommand
          when "submit"
            handle_blueprint_submit
          when "list"
            handle_blueprint_list
          when "browse"
            execute_blueprint_command("browse")
          when "view"
            handle_blueprint_view
          when "edit"
            handle_blueprint_edit
          when "delete"
            handle_blueprint_delete
          when "search"
            handle_blueprint_search
          when "export"
            handle_blueprint_export
          when "config"
            handle_blueprint_config
          end
        rescue StandardError => e
          puts "❌ Error executing blueprint command: #{e.message}".colorize(:red)
        end

        :continue
      end

      # Handles the Deepgram command submenu and operations.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_deepgram_command
        debug_log("Entering handle_deepgram_command")
        subcommand = @prompt.select("🎙️ Deepgram - Choose operation:".colorize(:blue)) do |menu|
          menu.choice "Parse JSON output", "parse"
          menu.choice "Analyze with AI insights", "analyze"
          menu.choice "Convert to different format", "convert"
          menu.choice "Configuration", "config"
          menu.choice "Back to main menu", :back
        end

        return :continue if subcommand == :back

        begin
          case subcommand
          when "parse"
            handle_deepgram_parse
          when "analyze"
            handle_deepgram_analyze
          when "convert"
            handle_deepgram_convert
          when "config"
            execute_deepgram_command("config")
          end
        rescue StandardError => e
          puts "❌ Error executing deepgram command: #{e.message}".colorize(:red)
        end

        :continue
      end

      # Handles the example command, displaying sample output.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_example_command
        debug_log("Entering handle_example_command")
        puts "🎯 Running example command...".colorize(:green)
        begin
          example_text = "This is a simple example story: Once upon a time, ComputerTools was created to help " \
                         "developers manage their code blueprints and process Deepgram audio transcriptions. The end!"
          puts example_text.colorize(:yellow)
          @prompt.keypress("Press any key to continue...")
        rescue StandardError => e
          puts "❌ Error running example: #{e.message}".colorize(:red)
        end
        :continue
      end

      # Handles the latest changes command submenu and operations.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_latest_changes_command
        debug_log("Entering handle_latest_changes_command")

        subcommand = @prompt.select("📊 Latest Changes - Choose operation:".colorize(:blue)) do |menu|
          menu.choice "Analyze recent changes", "analyze"
          menu.choice "Configure settings", "config"
          menu.choice "Help", "help"
          menu.choice "Back to main menu", :back
        end

        return :continue if subcommand == :back

        case subcommand
        when "analyze"
          handle_latest_changes_analyze
        when "config"
          handle_latest_changes_config
        when "help"
          handle_latest_changes_help
        end
        :continue
      end

      # Executes a blueprint command with the given subcommand and arguments.
      #
      # @param subcommand [String] the blueprint subcommand to execute
      # @param args [Array] additional arguments for the command
      # @return [void]
      def execute_blueprint_command(subcommand, *)
        blueprint_command = ComputerTools::Commands::BlueprintCommand.new({})
        blueprint_command.execute(subcommand, *)
      end

      # Executes a Deepgram command with the given subcommand and arguments.
      #
      # @param subcommand [String] the Deepgram subcommand to execute
      # @param args [Array] additional arguments for the command
      # @return [void]
      def execute_deepgram_command(subcommand, *)
        deepgram_command = ComputerTools::Commands::DeepgramCommand.new({})
        deepgram_command.execute(subcommand, *)
      end

      # Handles the blueprint submission process.
      # Prompts the user for input and options, then executes the submit command.
      #
      # @return [void]
      def handle_blueprint_submit
        input = @prompt.ask("📁 Enter file path or code string:")
        return if input.nil? || input.empty?

        auto_describe = @prompt.yes?("🤖 Auto-generate description?")
        auto_categorize = @prompt.yes?("🏷️ Auto-categorize?")

        args = [input]
        options = {}
        options['auto_describe'] = false unless auto_describe
        options['auto_categorize'] = false unless auto_categorize

        blueprint_command = ComputerTools::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('submit', *args)
      end

      # Handles listing blueprints with various format options.
      #
      # @return [void]
      def handle_blueprint_list
        format = @prompt.select("📊 Choose format:") do |menu|
          menu.choice "Table", "table"
          menu.choice "Summary", "summary"
          menu.choice "JSON", "json"
        end

        interactive = @prompt.yes?("🔄 Interactive mode?")

        options = { 'format' => format }
        options['interactive'] = true if interactive

        blueprint_command = ComputerTools::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('list')
      end

      # Handles viewing a specific blueprint with various format options.
      #
      # @return [void]
      def handle_blueprint_view
        id = @prompt.ask("🔍 Enter blueprint ID:")
        return if id.nil? || id.empty?

        format = @prompt.select("📊 Choose format:") do |menu|
          menu.choice "Detailed", "detailed"
          menu.choice "Summary", "summary"
          menu.choice "JSON", "json"
        end

        analyze = @prompt.yes?("🧠 Include AI analysis?")

        options = { 'format' => format }
        options['analyze'] = true if analyze

        blueprint_command = ComputerTools::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('view', id)
      end

      # Handles editing a blueprint.
      #
      # @return [void]
      def handle_blueprint_edit
        id = @prompt.ask("✏️ Enter blueprint ID to edit:")
        return if id.nil? || id.empty?

        blueprint_command = ComputerTools::Commands::BlueprintCommand.new({})
        blueprint_command.execute('edit', id)
      end

      # Handles deleting a blueprint with options for ID input or interactive selection.
      #
      # @return [void]
      def handle_blueprint_delete
        choice = @prompt.select("🗑️ How would you like to select the blueprint to delete?") do |menu|
          menu.choice "Enter blueprint ID", "id"
          menu.choice "Select from list", "interactive"
        end

        case choice
        when "id"
          id = @prompt.ask("🗑️ Enter blueprint ID to delete:")
          return if id.nil? || id.empty?

          force = @prompt.yes?("⚠️ Skip confirmation? (Use with caution)")

          args = [id]
          args << "--force" if force

          blueprint_command = ComputerTools::Commands::BlueprintCommand.new({})
          blueprint_command.execute('delete', *args)
        when "interactive"
          blueprint_command = ComputerTools::Commands::BlueprintCommand.new({})
          blueprint_command.execute('delete')
        end
      end

      # Handles searching blueprints with query and limit options.
      #
      # @return [void]
      def handle_blueprint_search
        query = @prompt.ask("🔍 Enter search query:")
        return if query.nil? || query.empty?

        limit = @prompt.ask("📊 Number of results (default 10):", default: "10")

        options = { 'limit' => limit.to_i }
        blueprint_command = ComputerTools::Commands::BlueprintCommand.new(options)
        blueprint_command.execute('search', query)
      end

      # Handles exporting a blueprint with optional output path.
      #
      # @return [void]
      def handle_blueprint_export
        id = @prompt.ask("📤 Enter blueprint ID to export:")
        return if id.nil? || id.empty?

        output_path = @prompt.ask("💾 Output file path (optional):")

        args = [id]
        args << output_path unless output_path.nil? || output_path.empty?

        blueprint_command = ComputerTools::Commands::BlueprintCommand.new({})
        blueprint_command.execute('export', *args)
      end

      # Handles blueprint configuration options.
      #
      # @return [void]
      def handle_blueprint_config
        subcommand = @prompt.select("⚙️ Configuration:") do |menu|
          menu.choice "Show current config", "show"
          menu.choice "Setup configuration", "setup"
        end

        blueprint_command = ComputerTools::Commands::BlueprintCommand.new({})
        blueprint_command.execute('config', subcommand)
      end

      # Handles parsing Deepgram JSON output with various format options.
      #
      # @return [void]
      def handle_deepgram_parse
        json_file = @prompt.ask("📁 Enter JSON file path:")
        return if json_file.nil? || json_file.empty?

        format = @prompt.select("📊 Choose output format:") do |menu|
          menu.choice "Markdown", "markdown"
          menu.choice "SRT", "srt"
          menu.choice "JSON", "json"
          menu.choice "Summary", "summary"
        end

        console_output = @prompt.yes?("🖥️ Display in console?")
        output_file = @prompt.ask("💾 Output file path (optional):")

        args = [json_file, format]
        options = {}
        options['console'] = true if console_output
        options['output'] = output_file unless output_file.nil? || output_file.empty?

        deepgram_command = ComputerTools::Commands::DeepgramCommand.new(options)
        deepgram_command.execute('parse', *args)
      end

      # Handles analyzing Deepgram output with AI insights.
      #
      # @return [void]
      def handle_deepgram_analyze
        json_file = @prompt.ask("📁 Enter JSON file path:")
        return if json_file.nil? || json_file.empty?

        interactive = @prompt.yes?("🔄 Interactive mode?")
        console_output = @prompt.yes?("🖥️ Display in console?")

        options = {}
        options['interactive'] = true if interactive
        options['console'] = true if console_output

        deepgram_command = ComputerTools::Commands::DeepgramCommand.new(options)
        deepgram_command.execute('analyze', json_file)
      end

      # Handles converting Deepgram output to different formats.
      #
      # @return [void]
      def handle_deepgram_convert
        json_file = @prompt.ask("📁 Enter JSON file path:")
        return if json_file.nil? || json_file.empty?

        format = @prompt.select("📊 Choose target format:") do |menu|
          menu.choice "Markdown", "markdown"
          menu.choice "SRT", "srt"
          menu.choice "JSON", "json"
          menu.choice "Summary", "summary"
        end

        console_output = @prompt.yes?("🖥️ Display in console?")
        output_file = @prompt.ask("💾 Output file path (optional):")

        args = [json_file, format]
        options = {}
        options['console'] = true if console_output
        options['output'] = output_file unless output_file.nil? || output_file.empty?

        deepgram_command = ComputerTools::Commands::DeepgramCommand.new(options)
        deepgram_command.execute('convert', *args)
      end

      # Handles analyzing recent changes with various time range and format options.
      #
      # @return [void]
      def handle_latest_changes_analyze
        directory = @prompt.ask("📁 Directory to analyze (default: current):", default: ".")

        time_range = @prompt.select("⏰ Time range:") do |menu|
          menu.choice "Last hour", "1h"
          menu.choice "Last 6 hours", "6h"
          menu.choice "Last 24 hours", "24h"
          menu.choice "Last 2 days", "2d"
          menu.choice "Last week", "7d"
          menu.choice "Custom", "custom"
        end

        if time_range == "custom"
          time_range = @prompt.ask("Enter custom time range (e.g., 3h, 5d, 2w):")
        end

        format = @prompt.select("📊 Output format:") do |menu|
          menu.choice "Table", "table"
          menu.choice "Summary", "summary"
          menu.choice "JSON", "json"
        end

        interactive = @prompt.yes?("🔄 Interactive mode?")

        options = {
          'directory' => directory,
          'time_range' => time_range,
          'format' => format
        }
        options['interactive'] = true if interactive

        latest_changes_command = ComputerTools::Commands::LatestChangesCommand.new(options)
        latest_changes_command.execute('analyze')
      end

      # Handles latest changes configuration.
      #
      # @return [void]
      def handle_latest_changes_config
        latest_changes_command = ComputerTools::Commands::LatestChangesCommand.new({})
        latest_changes_command.execute('config')
      end

      # Displays help information for latest changes command.
      #
      # @return [void]
      def handle_latest_changes_help
        latest_changes_command = ComputerTools::Commands::LatestChangesCommand.new({})
        latest_changes_command.execute('help')
      end

      # Handles configuration commands with various sub-options.
      #
      # @return [Symbol] :continue to keep the menu running
      def handle_config_command
        debug_log("Entering handle_config_command")

        subcommand = @prompt.select("⚙️ Configuration - Choose operation:".colorize(:blue)) do |menu|
          menu.choice "🔧 Setup configuration", "setup"
          menu.choice "📋 Show current config", "show"
          menu.choice "✏️ Edit configuration", "edit"
          menu.choice "🔍 Validate configuration", "validate"
          menu.choice "🔄 Reset configuration", "reset"
          menu.choice "❓ Help", "help"
          menu.choice "Back to main menu", :back
        end

        return :continue if subcommand == :back

        begin
          config_command = ComputerTools::Commands::ConfigCommand.new({})
          config_command.execute(subcommand)
        rescue StandardError => e
          puts "❌ Error executing config command: #{e.message}".colorize(:red)
        end

        :continue
      end
    end
  end
end