# frozen_string_literal: true

require_relative 'cli_ui_integration'
require_relative 'slash_command_parser'
require_relative 'autocomplete_handler'
require_relative 'readline_integration'

module BlueprintsCLI
  # EnhancedMenu provides an advanced interactive interface with slash commands
  # and autocomplete functionality using CLI-UI framework
  class EnhancedMenu
    def initialize
      @running = true
      @autocomplete_handler = AutocompleteHandler.new
      CLIUIIntegration.initialize!
      setup_autocomplete
    end

    # Start the enhanced interactive session
    def start
      show_welcome_banner

      loop do
        break unless @running

        begin
          handle_user_input
        rescue Interrupt, EOFError
          handle_exit
          break
        rescue StandardError => e
          CLIUIIntegration.puts("{{red:Error: #{e.message}}}")
          BlueprintsCLI.logger.error("Enhanced menu error: #{e.message}")
        end
      end
    end

    private

    def setup_autocomplete
      # Initialize readline with our autocomplete handler
      success = ReadlineIntegration.setup_readline(@autocomplete_handler)

      if success
        BlueprintsCLI.logger.debug('Autocomplete functionality enabled')
      else
        BlueprintsCLI.logger.warn('Autocomplete functionality not available, falling back to basic input')
      end
    end

    def show_welcome_banner
      CLIUIIntegration.frame('🚀 BlueprintsCLI Enhanced Interactive Mode', color: :cyan) do
        CLIUIIntegration.puts('{{green:Welcome to BlueprintsCLI!}}')
        CLIUIIntegration.puts('')
        CLIUIIntegration.puts('{{yellow:💡 Tips:}}')
        CLIUIIntegration.puts('  • Use slash commands: {{blue:/blueprint submit}}, {{blue:/search ruby}}')
        CLIUIIntegration.puts('  • Press {{blue:TAB}} for autocomplete')
        CLIUIIntegration.puts('  • Type {{blue:/help}} for available commands')
        CLIUIIntegration.puts('  • Type {{blue:/exit}} or press {{blue:Ctrl+C}} to quit')
        CLIUIIntegration.puts('')
      end
    end

    def handle_user_input
      # Get user input with support for slash commands
      input = get_user_input

      return if input.nil? || input.empty?

      # Check if it's a slash command
      parser = SlashCommandParser.new(input)

      if parser.slash_command?
        if parser.valid?
          result = parser.execute
          unless result
            CLIUIIntegration.puts('{{yellow:Command failed or incomplete. Try {{blue:/help}} for assistance.}}')
          end
        else
          handle_invalid_slash_command(parser)
        end
      else
        # Handle regular text input (could be used for search, etc.)
        handle_regular_input(input)
      end
    end

    def get_user_input
      # Custom prompt with slash command support and autocomplete
      CLIUIIntegration.raw_puts('')
      prompt = "#{::CLI::UI.fmt('{{cyan:blueprintsCLI}}')} #{::CLI::UI.fmt('{{blue:>}}')} "

      # Use readline integration for autocomplete support
      ReadlineIntegration.readline_input(prompt, true)
    end

    def handle_invalid_slash_command(parser)
      CLIUIIntegration.puts("{{red:Invalid command: #{parser.input}}}")

      # Suggest completions if available
      completions = parser.completions
      if completions.any?
        CLIUIIntegration.puts('{{yellow:Did you mean:}}')
        completions.first(5).each do |completion|
          CLIUIIntegration.puts("  {{blue:#{completion}}}")
        end
      else
        CLIUIIntegration.puts('Type {{blue:/help}} to see available commands.')
      end
    end

    def handle_regular_input(input)
      # If it's not a slash command, treat it as a search query
      if input.strip.length > 2
        CLIUIIntegration.puts("{{yellow:Searching for: \"#{input}\"...}}")

        begin
          blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new({})
          blueprint_command.execute('search', input)
        rescue StandardError => e
          CLIUIIntegration.puts("{{red:Search failed: #{e.message}}}")
        end
      else
        CLIUIIntegration.puts('{{yellow:Enter a slash command or search term. Type {{blue:/help}} for assistance.}}')
      end
    end

    def handle_exit
      CLIUIIntegration.puts('')
      CLIUIIntegration.puts('{{green:👋 Thank you for using BlueprintsCLI!}}')
      @running = false
    end

    # Enhanced menu selection with CLI-UI for fallback scenarios
    def show_traditional_menu
      CLIUIIntegration.frame('Choose an option', color: :blue) do
        choice = CLIUIIntegration.select('What would you like to do?') do |menu|
          menu.option('📋 Manage Blueprints') { :blueprints }
          menu.option('⚙️ Configuration') { :config }
          menu.option('📖 Documentation') { :docs }
          menu.option('🔧 Setup') { :setup }
          menu.option('🔍 Quick Search') { :search }
          menu.option('❓ Help') { :help }
          menu.option('🚪 Exit') { :exit }
        end

        handle_traditional_choice(choice)
      end
    end

    def handle_traditional_choice(choice)
      case choice
      when :blueprints
        parser = SlashCommandParser.new('/blueprint')
        parser.execute
      when :config
        parser = SlashCommandParser.new('/config')
        parser.execute
      when :docs
        parser = SlashCommandParser.new('/docs')
        parser.execute
      when :setup
        parser = SlashCommandParser.new('/setup')
        parser.execute
      when :search
        query = CLIUIIntegration.ask('Enter search query:')
        parser = SlashCommandParser.new("/search #{query}")
        parser.execute
      when :help
        parser = SlashCommandParser.new('/help')
        parser.execute
      when :exit
        handle_exit
      end
    end
  end
end
