# frozen_string_literal: true

require_relative 'base_command'
require_relative '../services/yardoc_service'

module BlueprintsCLI
  module Commands
    # Command to handle YARD documentation generation.
    class DocsCommand < BaseCommand
      # Provides a description of what this command does.
      # @return [String] A description of the command's purpose.
      def self.description
        'Generate YARD documentation for Ruby files.'
      end

      # Initializes a new DocsCommand instance.
      # @param [Hash] options The options to configure the command.
      def initialize(options)
        super
        @prompt = TTY::Prompt.new
      end

      # Executes the docs command.
      # @param [Array<String>] args The arguments to pass to the command.
      def execute(*args)
        subcommand = args.shift
        case subcommand
        when 'generate'
          handle_generate(args.first)
        when 'help', nil
          show_help
        else
          puts "Unknown subcommand: #{subcommand}".colorize(:red)
          show_help
          false
        end
      end

      private

      def handle_generate(file_path)
        if file_path.nil?
          puts "Please provide a file path.".colorize(:red)
          show_help
          return false
        end

        absolute_path = File.expand_path(file_path)
        service = BlueprintsCLI::Services::YardocService.new(absolute_path)
        service.call
      end

      def show_help
        puts <<~HELP
          Usage: blueprintsCLI docs <subcommand> [options]

          Subcommands:
            generate <file_path>   - Generates YARD documentation for the specified file.
            help                     - Shows this help message.
        HELP
      end
    end
  end
end
