# frozen_string_literal: true

require_relative 'base_command'

module BlueprintsCLI
  module Commands
    # SetupCommand provides first-time setup and configuration management
    # for BlueprintsCLI. It guides users through AI provider configuration,
    # database setup, and application preferences.
    class SetupCommand < BaseCommand
      # Provides a description of what this command does.
      # @return [String] A description of the command's purpose.
      def self.description
        'Run first-time setup wizard for BlueprintsCLI configuration'
      end

      # Initializes a new SetupCommand instance.
      # @param [Hash] options The options to configure the command.
      def initialize(options)
        super
        @prompt = TTY::Prompt.new
      end

      # Executes the setup command.
      # @param [Array<String>] args The arguments to pass to the command.
      def execute(*args)
        subcommand = args.shift
        case subcommand
        when 'wizard', 'run', nil
          run_setup_wizard
        when 'providers'
          setup_providers_only
        when 'database'
          setup_database_only
        when 'models'
          setup_models_only
        when 'verify'
          verify_setup
        when 'help'
          show_help
        else
          log_failure("Unknown subcommand: #{subcommand}")
          show_help
          false
        end
      end

      private

      # Run the complete setup wizard
      #
      # @return [Boolean] True if setup completed successfully
      def run_setup_wizard
        log_step("Starting BlueprintsCLI setup wizard...")

        begin
          setup_manager = BlueprintsCLI::Setup::SetupManager.new
          
          # Check if setup is needed
          unless setup_manager.setup_required?
            log_info("Setup skipped by user")
            return true
          end

          # Run complete setup
          success = setup_manager.run
          
          if success
            log_success("Setup completed successfully!")
            display_next_steps
          else
            log_failure("Setup was not completed")
          end

          success
        rescue BlueprintsCLI::Setup::SetupManager::SetupCancelledError
          log_info("Setup cancelled by user")
          true
        rescue StandardError => e
          log_failure("Setup failed: #{e.message}")
          log_debug(e.backtrace.join("\n"))
          false
        end
      end

      # Setup only AI providers
      #
      # @return [Boolean] True if provider setup completed
      def setup_providers_only
        log_step("Setting up AI providers...")

        begin
          setup_manager = BlueprintsCLI::Setup::SetupManager.new
          success = setup_manager.setup_providers
          
          if success
            log_success("Provider setup completed!")
          else
            log_failure("Provider setup failed")
          end

          success
        rescue StandardError => e
          log_failure("Provider setup failed: #{e.message}")
          log_debug(e.backtrace.join("\n"))
          false
        end
      end

      # Setup only database
      #
      # @return [Boolean] True if database setup completed
      def setup_database_only
        log_step("Setting up database...")

        begin
          setup_manager = BlueprintsCLI::Setup::SetupManager.new
          success = setup_manager.setup_database
          
          if success
            log_success("Database setup completed!")
          else
            log_failure("Database setup failed")
          end

          success
        rescue StandardError => e
          log_failure("Database setup failed: #{e.message}")
          log_debug(e.backtrace.join("\n"))
          false
        end
      end

      # Setup only AI models
      #
      # @return [Boolean] True if model setup completed
      def setup_models_only
        log_step("Setting up AI models...")

        begin
          setup_manager = BlueprintsCLI::Setup::SetupManager.new
          success = setup_manager.setup_models
          
          if success
            log_success("Model setup completed!")
          else
            log_failure("Model setup failed")
          end

          success
        rescue StandardError => e
          log_failure("Model setup failed: #{e.message}")
          log_debug(e.backtrace.join("\n"))
          false
        end
      end

      # Verify current setup
      #
      # @return [Boolean] True if verification passed
      def verify_setup
        log_step("Verifying BlueprintsCLI setup...")

        begin
          config = BlueprintsCLI::Configuration.new
          
          # Check configuration file exists
          if config.exist?
            log_success("✓ Configuration file found")
          else
            log_failure("✗ Configuration file missing")
            log_tip("Run 'bin/blueprintsCLI setup' to create configuration")
            return false
          end

          # Check database configuration
          database_url = config.database_url
          if database_url
            log_success("✓ Database URL configured")
            verify_database_connection(database_url)
          else
            log_failure("✗ Database URL not configured")
          end

          # Check AI provider configuration
          verify_ai_providers(config)

          # Check required directories
          verify_directories

          log_success("Setup verification completed!")
          true
        rescue StandardError => e
          log_failure("Setup verification failed: #{e.message}")
          log_debug(e.backtrace.join("\n"))
          false
        end
      end

      # Verify database connection
      #
      # @param database_url [String] Database URL to test
      def verify_database_connection(database_url)
        begin
          require 'sequel'
          db = Sequel.connect(database_url)
          db.test_connection
          log_success("✓ Database connection successful")
          db.disconnect
        rescue StandardError => e
          log_failure("✗ Database connection failed: #{e.message}")
        end
      end

      # Verify AI provider configuration
      #
      # @param config [BlueprintsCLI::Configuration] Configuration instance
      def verify_ai_providers(config)
        providers = %w[openai anthropic gemini deepseek]
        found_providers = []

        providers.each do |provider|
          api_key = config.ai_api_key(provider)
          if api_key && !api_key.empty?
            log_success("✓ #{provider.capitalize} API key found")
            found_providers << provider
          end
        end

        if found_providers.empty?
          log_failure("✗ No AI provider API keys found")
          log_tip("Set environment variables for your AI providers")
        else
          log_info("Found #{found_providers.size} configured AI provider(s)")
        end
      end

      # Verify required directories exist
      def verify_directories
        log_file_dir = File.dirname(BlueprintsCLI.configuration.fetch(:logger, :file_path, default: '/tmp/app.log'))
        
        if Dir.exist?(log_file_dir)
          log_success("✓ Log directory exists")
        else
          log_warning("⚠ Log directory missing: #{log_file_dir}")
          log_tip("Directory will be created automatically when needed")
        end
      end

      # Display next steps after successful setup
      def display_next_steps
        puts "\n🎉 Welcome to BlueprintsCLI!"
        puts "\nNext steps:"
        puts "• Run 'bin/blueprintsCLI' to access the interactive menu"
        puts "• Try 'bin/blueprintsCLI blueprint list' to see existing blueprints"
        puts "• Submit your first blueprint with 'bin/blueprintsCLI blueprint submit'"
        puts "• Generate documentation with 'bin/blueprintsCLI docs generate'"
        puts "\nFor help: bin/blueprintsCLI help"
      end

      # Show help information
      def show_help
        puts <<~HELP
          Usage: blueprintsCLI setup <subcommand> [options]

          Subcommands:
            wizard                 - Run complete setup wizard (default)
            providers             - Setup AI providers only
            database              - Setup database only
            models                - Setup AI models only
            verify                - Verify current setup
            help                  - Show this help message

          Examples:
            bin/blueprintsCLI setup
            bin/blueprintsCLI setup wizard
            bin/blueprintsCLI setup providers
            bin/blueprintsCLI setup verify

          The setup wizard will guide you through:
          • AI provider configuration (OpenAI, Anthropic, Gemini, etc.)
          • Database setup with PostgreSQL and pgvector
          • Model selection and configuration
          • Application preferences and logging

          For first-time users, run the complete wizard to configure everything.
        HELP
      end
    end
  end
end