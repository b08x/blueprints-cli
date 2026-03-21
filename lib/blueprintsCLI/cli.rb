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
    def blueprint(*)
      BlueprintsCLI::Commands::BlueprintCommand.new(options).execute(*)
    end

    desc "config", "Manage application configuration"
    def config(*)
      BlueprintsCLI::Commands::ConfigCommand.new(options).execute(*)
    end

    desc "docs", "Generate and view project documentation"
    def docs(*)
      BlueprintsCLI::Commands::DocsCommand.new(options).execute(*)
    end

    desc "embedding", "Manage blueprint embeddings and Ollama connectivity"
    def embedding(*)
      BlueprintsCLI::Commands::EmbeddingCommand.new(options).execute(*)
    end

    desc "setup", "Initial environment setup"
    def setup(*)
      BlueprintsCLI::Commands::SetupCommand.new(options).execute(*)
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
          require "tty-prompt"
          debug_mode = ENV["BlueprintsCLI_DEBUG"] == "true"
          BlueprintsCLI::Commands::MenuCommand.new(debug: debug_mode).start
        rescue LoadError
          BlueprintsCLI.logger.failure("TTY::Prompt not available. Please run: bundle install. #{e.message}")
          super
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
