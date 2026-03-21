# frozen_string_literal: true

module BlueprintsCLI
  module Commands
    ##
    # EmbeddingCommand handles embedding generation and management operations.
    # This command provides utilities for processing blueprints with missing
    # embeddings and checking Ollama connectivity status.
    #
    # The command follows a subcommand pattern where the first argument determines
    # the specific embedding operation to perform.
    #
    # @example Process missing embeddings
    #   BlueprintsCLI::Commands::EmbeddingCommand.new({}).execute('process')
    #
    # @example Check Ollama status
    #   BlueprintsCLI::Commands::EmbeddingCommand.new({}).execute('status')
    class EmbeddingCommand < BaseCommand
      ##
      # Provides a description of what this command does, used in help text
      #
      # @return [String] A description of the command's purpose
      def self.description
        'Manage blueprint embeddings and Ollama connectivity'
      end

      ##
      # Initializes a new EmbeddingCommand instance
      #
      # @param [Hash] options The options to configure the command
      def initialize(options)
        super
        @db = BlueprintsCLI::BlueprintDatabase.new
        @prompt = TTY::Prompt.new
      end

      ##
      # Executes the embedding command with the provided arguments
      #
      # @param [Array] args The arguments passed to the command
      # @return [Boolean] true if the operation succeeded, false otherwise
      def execute(*args)
        subcommand = args.shift&.downcase || 'help'

        case subcommand
        when 'process'
          process_missing_embeddings
        when 'status'
          check_ollama_status
        when 'help'
          show_help
        else
          BlueprintsCLI.logger.failure("Unknown subcommand: #{subcommand}")
          show_help
          false
        end
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error executing embedding command: #{e.message}")
        BlueprintsCLI.logger.debug(e) if ENV['DEBUG']
        false
      end

      private

      ##
      # Process all blueprints with missing embeddings
      def process_missing_embeddings
        BlueprintsCLI.logger.step('Processing blueprints with missing embeddings...')

        # Check Ollama availability first
        unless @db.ollama_available?
          BlueprintsCLI.logger.failure('Ollama service is not available. Please ensure Ollama is running and accessible.')
          BlueprintsCLI.logger.info('Check your OLLAMA_API_BASE environment variable or ensure Ollama is running on http://localhost:11434')
          return false
        end

        # Process missing embeddings
        result = @db.generate_missing_embeddings(batch_size: 50)

        if result[:processed] > 0
          BlueprintsCLI.logger.success("Successfully processed #{result[:processed]} blueprint embeddings")
        end

        if result[:failed] > 0
          BlueprintsCLI.logger.warning("#{result[:failed]} blueprints failed to process")
        end

        if result[:skipped] > 0
          BlueprintsCLI.logger.warning("#{result[:skipped]} blueprints were skipped due to Ollama unavailability")
        end

        if result[:processed] == 0 && result[:total_found] == 0
          BlueprintsCLI.logger.info('No blueprints with missing embeddings found.')
        end

        true
      end

      ##
      # Check Ollama connectivity and embedding model availability
      def check_ollama_status
        BlueprintsCLI.logger.step('Checking Ollama service status...')

        if @db.ollama_available?
          BlueprintsCLI.logger.success('✓ Ollama service is available')

          # Check for missing embeddings
          missing_count = @db.db[:blueprints].where(embedding: nil).count

          if missing_count > 0
            BlueprintsCLI.logger.warning("⚠ Found #{missing_count} blueprint(s) with missing embeddings")
            BlueprintsCLI.logger.info("Run 'bin/blueprintsCLI embedding process' to generate missing embeddings")
          else
            BlueprintsCLI.logger.success('✓ All blueprints have embeddings')
          end
        else
          BlueprintsCLI.logger.failure('✗ Ollama service is not available')

          # Show configuration info
          config = BlueprintsCLI.configuration
          ollama_base = config.fetch(:ai, :rubyllm, :ollama_api_base, default: 'http://localhost:11434')
          BlueprintsCLI.logger.info("Configured Ollama API Base: #{ollama_base}")
          BlueprintsCLI.logger.info("Embedding Model: #{config.fetch(:ai, :rubyllm, :default_embedding_model)}")

          BlueprintsCLI.logger.info("\nTroubleshooting:")
          BlueprintsCLI.logger.info("1. Ensure Ollama is running: ollama serve")
          BlueprintsCLI.logger.info("2. Check if embeddinggemma model is available: ollama list | grep embeddinggemma")
          BlueprintsCLI.logger.info("3. Pull the model if missing: ollama pull embeddinggemma:latest")
          BlueprintsCLI.logger.info("4. Verify OLLAMA_API_BASE environment variable if using custom endpoint")
        end

        true
      end

      ##
      # Show help information for the embedding command
      def show_help
        BlueprintsCLI.logger.info(<<~HELP)
          Usage: bin/blueprintsCLI embedding <subcommand>

          Subcommands:
            process    Process all blueprints with missing embeddings
            status     Check Ollama connectivity and embedding status
            help       Show this help message

          Examples:
            bin/blueprintsCLI embedding process
            bin/blueprintsCLI embedding status
        HELP
        true
      end
    end
  end
end