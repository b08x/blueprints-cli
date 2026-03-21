# frozen_string_literal: true

module BlueprintsCLI
  # BlueprintsCLI::CLI is the main command line interface for BlueprintsCLI.
  # It extends Thor to provide a command-line interface with various computer-related utilities.
  # When no arguments are provided, it launches an interactive menu system.
  #
  # @example Basic usage with arguments
  #   BlueprintsCLI::CLI.start(['command_name', 'arg1', 'arg2'])
  # @example Interactive menu mode (no arguments)
  #   BlueprintsCLI::CLI.start
  class CLI < Thor
    desc "blueprint", "Manage code blueprints"
    def blueprint(*args)
      BlueprintsCLI::Commands::BlueprintCommand.new(options).execute(*args)
    end

    desc "config", "Manage application configuration"
    def config(*args)
      BlueprintsCLI::Commands::ConfigCommand.new(options).execute(*args)
    end

    desc "docs", "Generate and view project documentation"
    def docs(*args)
      BlueprintsCLI::Commands::DocsCommand.new(options).execute(*args)
    end

    desc "setup", "Initial environment setup"
    def setup(*args)
      BlueprintsCLI::Commands::SetupCommand.new(options).execute(*args)
    end

    # Starts the CLI application with the given arguments.
    #
    # When no arguments are provided, launches an interactive menu system.
    # Otherwise, processes the provided command line arguments.
    #
    # @param given_args [Array<String>] the command line arguments to process
    # @return [void]
    #
    # @example Starting with arguments
    #   BlueprintsCLI::CLI.start(['disk_usage', '/path/to/check'])
    #
    # @example Starting interactive menu
    #   BlueprintsCLI::CLI.start
    #
    # @note Requires 'tty-prompt' gem for interactive menu functionality
    # @note Set BlueprintsCLI_DEBUG=true environment variable for debug output
    def self.start(given_args = ARGV)
      # If no arguments provided, launch interactive menu
      if given_args.empty?
        # Check for enhanced menu option
        config = BlueprintsCLI.configuration
        enhanced_enabled = config.fetch(:ui, :enhanced_menu, default: true) ||
                           config.fetch(:ui, :slash_commands, default: true) ||
                           ENV['BLUEPRINTS_ENHANCED_MENU'] == 'true' ||
                           ENV['BLUEPRINTS_SLASH_COMMANDS'] == 'true'

        if enhanced_enabled
          begin
            BlueprintsCLI::SimpleEnhancedMenu.new.start
          rescue StandardError => e
            BlueprintsCLI.logger.failure("Enhanced menu failed: #{e.message}")
            # Fallback to traditional menu
            fallback_to_traditional_menu
          end
        else
          fallback_to_traditional_menu
        end
      else
        super
      end
    end

    def self.fallback_to_traditional_menu
      require 'tty-prompt'
      debug_mode = ENV['BlueprintsCLI_DEBUG'] == 'true'
      BlueprintsCLI::Commands::MenuCommand.new(debug: debug_mode).start
    rescue LoadError => e
      BlueprintsCLI.logger.failure("TTY::Prompt not available. Please run: bundle install. #{e.message}")
      super
    end
  end
end
