# frozen_string_literal: true

module BlueprintsCLI
  # SlashCommandParser handles parsing and execution of slash commands
  # Supports commands like /blueprint submit, /config show, /search query, etc.
  class SlashCommandParser
    # Command registry with their handlers
    COMMANDS = {
      'blueprint' => {
        description: 'Manage code blueprints',
        subcommands: %w[submit list browse view edit delete search export generate config],
        handler: :handle_blueprint_command
      },
      'config' => {
        description: 'Manage configuration',
        subcommands: %w[setup show edit validate reset help],
        handler: :handle_config_command
      },
      'docs' => {
        description: 'Generate documentation',
        subcommands: %w[generate help],
        handler: :handle_docs_command
      },
      'setup' => {
        description: 'Run setup wizard',
        subcommands: %w[wizard providers database models verify help],
        handler: :handle_setup_command
      },
      'search' => {
        description: 'Quick search blueprints',
        subcommands: [],
        handler: :handle_search_command
      },
      'help' => {
        description: 'Show help information',
        subcommands: [],
        handler: :handle_help_command
      },
      'exit' => {
        description: 'Exit the application',
        subcommands: [],
        handler: :handle_exit_command
      },
      'clear' => {
        description: 'Clear the screen',
        subcommands: [],
        handler: :handle_clear_command
      }
    }.freeze

    attr_reader :input, :command, :subcommand, :args, :options

    def initialize(input)
      @input = input.to_s.strip
      @command = nil
      @subcommand = nil
      @args = []
      @options = {}
      parse_input
    end

    # Check if the input is a valid slash command
    def slash_command?
      @input.start_with?('/')
    end

    # Parse the input into command components
    def parse_input
      return unless slash_command?

      # Remove leading slash and split into parts
      parts = @input[1..].split(/\s+/)
      return if parts.empty?

      @command = parts[0]
      remaining_parts = parts[1..]

      # Check if first remaining part is a subcommand
      if remaining_parts.any? && COMMANDS.dig(@command, :subcommands)&.include?(remaining_parts[0])
        @subcommand = remaining_parts[0]
        remaining_parts = remaining_parts[1..]
      end

      # Parse remaining parts into args and options
      parse_args_and_options(remaining_parts)
    end

    # Execute the parsed command
    def execute
      return false unless valid?

      handler_method = COMMANDS.dig(@command, :handler)
      return false unless handler_method

      send(handler_method)
    rescue StandardError => e
      CLIUIIntegration.puts("{{red:Error executing command: #{e.message}}}")
      false
    end

    # Check if the parsed command is valid
    def valid?
      slash_command? && COMMANDS.key?(@command)
    end

    # Get completion suggestions for the current input
    def completions
      return [] unless slash_command?

      if @command.nil? || @command.empty?
        # Complete command names with descriptions as context
        return COMMANDS.keys.map { |cmd| "/#{cmd}" }
      end

      # Find matching commands
      matching_commands = COMMANDS.keys.select { |cmd| cmd.start_with?(@command) }

      if matching_commands.size == 1 && matching_commands.first == @command
        # Complete subcommands with context-aware filtering
        subcommands = COMMANDS.dig(@command, :subcommands) || []

        if @subcommand.nil? || @subcommand.empty?
          return subcommands.map { |sub| "/#{@command} #{sub}" }
        end

        # Return all available subcommands

        # Filter subcommands based on partial input
        matching_subcommands = subcommands.select { |sub| sub.start_with?(@subcommand) }
        return matching_subcommands.map { |sub| "/#{@command} #{sub}" }

      elsif matching_commands.size > 1
        # Complete command names
        return matching_commands.map { |cmd| "/#{cmd}" }
      elsif @command && !matching_commands.empty?
        # Partial command match - show the completion
        return ["/#{matching_commands.first}"]
      end

      # No matches found - could suggest similar commands
      suggest_similar_commands
    end

    # Get contextual help for current completion state
    def completion_context
      return 'Available commands' if @command.nil? || @command.empty?

      if COMMANDS.key?(@command)
        if @subcommand.nil? || @subcommand.empty?
          "Subcommands for #{@command}"
        else
          "Options for #{@command} #{@subcommand}"
        end
      else
        'Did you mean...?'
      end
    end

    # Get help text for commands
    def help_text(cmd = nil)
      if cmd && COMMANDS.key?(cmd)
        command_help(cmd)
      else
        all_commands_help
      end
    end

    private

    def parse_args_and_options(parts)
      parts.each do |part|
        if part.start_with?('--')
          # Long option
          key_value = part[2..].split('=', 2)
          key = key_value[0]
          value = key_value.size > 1 ? key_value[1] : true
          @options[key] = value
        elsif part.start_with?('-')
          # Short option
          @options[part[1..]] = true
        else
          # Argument
          @args << part
        end
      end
    end

    # Command handlers
    def handle_blueprint_command
      blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new(@options)
      if @subcommand
        blueprint_command.execute(@subcommand, *@args)
      else
        blueprint_command.execute('help')
      end
      true
    end

    def handle_config_command
      config_command = BlueprintsCLI::Commands::ConfigCommand.new(@options)
      if @subcommand
        config_command.execute(@subcommand, *@args)
      else
        config_command.execute('show')
      end
      true
    end

    def handle_docs_command
      docs_command = BlueprintsCLI::Commands::DocsCommand.new(@options)
      if @subcommand
        docs_command.execute(@subcommand, *@args)
      else
        docs_command.execute('help')
      end
      true
    end

    def handle_setup_command
      setup_command = BlueprintsCLI::Commands::SetupCommand.new(@options)
      if @subcommand
        setup_command.execute(@subcommand, *@args)
      else
        setup_command.execute('wizard')
      end
      true
    end

    def handle_search_command
      if @args.empty?
        CLIUIIntegration.puts('{{yellow:Usage: /search <query>}}')
        return false
      end

      query = @args.join(' ')
      blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new(@options)
      blueprint_command.execute('search', query)
      true
    end

    def handle_help_command
      if @args.empty?
        CLIUIIntegration.puts(help_text)
      else
        CLIUIIntegration.puts(help_text(@args.first))
      end
      true
    end

    def handle_exit_command
      CLIUIIntegration.puts('{{green:👋 Goodbye!}}')
      exit(0)
    end

    def handle_clear_command
      system('clear') || system('cls')
      true
    end

    def command_help(cmd)
      command_info = COMMANDS[cmd]
      help = "{{cyan:#{cmd.upcase}}} - #{command_info[:description]}\n\n"

      subcommands = command_info[:subcommands]
      if subcommands.any?
        help += "{{yellow:Subcommands:}}\n"
        subcommands.each do |sub|
          help += "  /#{cmd} #{sub}\n"
        end
      end

      help += "\nExample: {{blue:/#{cmd}#{" #{subcommands.first}" if subcommands.first}}}"
      help
    end

    def all_commands_help
      help = "{{cyan:🚀 BlueprintsCLI Slash Commands}}\n\n"
      help += "{{yellow:Available Commands:}}\n"

      COMMANDS.each do |cmd, info|
        help += "  {{blue:/#{cmd}}} - #{info[:description]}\n"
      end

      help += "\n{{yellow:Tips:}}\n"
      help += "  • Type {{blue:/}} and press TAB for autocomplete\n"
      help += "  • Use {{blue:/help <command>}} for detailed help\n"
      help += "  • Use {{blue:/clear}} to clear the screen\n"
      help += '  • Use {{blue:/exit}} to quit the application'

      help
    end

    # Suggest similar commands using basic string similarity
    def suggest_similar_commands
      return [] if @command.nil? || @command.empty?

      # Simple similarity based on shared prefixes and substrings
      suggestions = COMMANDS.keys.select do |cmd|
        # Commands that contain our input or our input contains them
        cmd.include?(@command) || @command.include?(cmd) ||
          # Commands with similar starting characters
          (cmd.length > 2 && @command.length > 2 && cmd[0..1] == @command[0..1])
      end

      suggestions.map { |cmd| "/#{cmd}" }.first(3)
    end
  end
end
