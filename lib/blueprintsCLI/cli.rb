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
    # Dynamically registers all available commands from BlueprintsCLI::Commands
    # as Thor commands, excluding the base and menu commands.
    #
    # This is automatically executed when the class is loaded and sets up
    # the command descriptions and method definitions for each available command.
    excluded_commands = %i[BaseCommand MenuCommand]
    valid_commands = BlueprintsCLI::Commands.constants.reject do |command_class|
      excluded_commands.include?(command_class)
    end

    valid_commands.each do |command_class|
      command = BlueprintsCLI::Commands.const_get(command_class)
      desc command.command_name, command.description
      define_method(command.command_name) do |*args|
        command.new(options).execute(*args)
      end
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
        begin
          require 'tty-prompt'
          debug_mode = ENV['BlueprintsCLI_DEBUG'] == 'true'
          BlueprintsCLI::Commands::MenuCommand.new(debug: debug_mode).start
        rescue LoadError
          BlueprintsCLI.logger.failure("TTY::Prompt not available. Please run: bundle install. #{e.message}")
          super
        end
      else
        super
      end
    end
  end
end
