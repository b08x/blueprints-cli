# frozen_string_literal: true

require_relative 'slash_command_parser'

module BlueprintsCLI
  # SimpleEnhancedMenu provides slash command functionality without CLI-UI conflicts
  class SimpleEnhancedMenu
    def initialize
      @running = true
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
          puts "\e[31mError: #{e.message}\e[0m"
          BlueprintsCLI.logger.error("Enhanced menu error: #{e.message}")
        end
      end
    end

    private

    def show_welcome_banner
      puts "\e[36m#{'=' * 70}\e[0m"
      puts "\e[36m🚀 BlueprintsCLI Enhanced Interactive Mode\e[0m"
      puts "\e[36m#{'=' * 70}\e[0m"
      puts ''
      puts "\e[32mWelcome to BlueprintsCLI!\e[0m"
      puts ''
      puts "\e[33m💡 Tips:\e[0m"
      puts "  • Use slash commands: \e[34m/blueprint submit\e[0m, \e[34m/search ruby\e[0m"
      puts "  • Type \e[34m/help\e[0m for available commands"
      puts "  • Type \e[34m/exit\e[0m or press \e[34mCtrl+C\e[0m to quit"
      puts ''
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
            puts "\e[33mCommand failed or incomplete. Try \e[34m/help\e[0m for assistance.\e[0m"
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
      puts ''
      print "\e[36mblueprintsCLI\e[0m \e[34m>\e[0m "

      input = $stdin.gets
      if input.nil?
        @running = false
        return nil
      end

      input.chomp.strip
    end

    def handle_invalid_slash_command(parser)
      puts "\e[31mInvalid command: #{parser.input}\e[0m"

      # Suggest completions if available
      completions = parser.completions
      if completions.any?
        puts "\e[33mDid you mean:\e[0m"
        completions.first(5).each do |completion|
          puts "  \e[34m#{completion}\e[0m"
        end
      else
        puts "Type \e[34m/help\e[0m to see available commands."
      end
    end

    def handle_regular_input(input)
      # If it's not a slash command, treat it as a search query
      if input.strip.length > 2
        puts "\e[33mSearching for: \"#{input}\"...\e[0m"

        begin
          blueprint_command = BlueprintsCLI::Commands::BlueprintCommand.new({})
          blueprint_command.execute('search', input)
        rescue StandardError => e
          puts "\e[31mSearch failed: #{e.message}\e[0m"
        end
      else
        puts "\e[33mEnter a slash command or search term. Type \e[34m/help\e[0m for assistance.\e[0m"
      end
    end

    def handle_exit
      puts ''
      puts "\e[32m👋 Thank you for using BlueprintsCLI!\e[0m"
      @running = false
    end
  end
end
