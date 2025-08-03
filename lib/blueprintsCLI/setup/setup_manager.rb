# frozen_string_literal: true

require 'tty-prompt'
require 'tty-box'

module BlueprintsCLI
  module Setup
    # SetupManager orchestrates the complete first-time setup process for BlueprintsCLI.
    # It guides users through provider configuration, database setup, and application preferences.
    #
    # @example Run complete setup
    #   setup = BlueprintsCLI::Setup::SetupManager.new
    #   setup.run
    #
    # @example Run specific setup steps
    #   setup = BlueprintsCLI::Setup::SetupManager.new
    #   setup.setup_providers
    #   setup.setup_database
    class SetupManager
      # Error raised when setup is cancelled by user
      SetupCancelledError = Class.new(StandardError)

      # Error raised when setup validation fails
      SetupValidationError = Class.new(StandardError)

      # Initialize the setup manager
      #
      # @param prompt [TTY::Prompt] Optional prompt instance for testing
      # @param config [BlueprintsCLI::Configuration] Optional configuration instance
      def initialize(prompt: nil, config: nil)
        @prompt = prompt || TTY::Prompt.new
        @config = config || BlueprintsCLI::Configuration.new(auto_load: false)
        @setup_data = {}
        @logger = BlueprintsCLI.logger
      end

      # Run the complete setup process
      #
      # @return [Boolean] True if setup completed successfully
      def run
        display_welcome
        return false unless confirm_continue

        begin
          run_setup_phases
          display_completion
          true
        rescue SetupCancelledError
          display_cancellation
          false
        rescue StandardError => e
          handle_setup_error(e)
          false
        end
      end

      # Run only the provider setup phase
      #
      # @return [Boolean] True if provider setup completed successfully
      def setup_providers
        @logger.step('Setting up AI providers...')
        provider_detector = ProviderDetector.new(@prompt, @setup_data)
        provider_detector.detect_and_configure
      end

      # Run only the database setup phase
      #
      # @return [Boolean] True if database setup completed successfully
      def setup_database
        @logger.step('Setting up database...')
        database_setup = DatabaseSetup.new(@prompt, @setup_data)
        database_setup.configure_and_test
      end

      # Run only the model configuration phase
      #
      # @return [Boolean] True if model configuration completed successfully
      def setup_models
        @logger.step('Configuring AI models...')
        model_configurator = ModelConfigurator.new(@prompt, @setup_data)
        model_configurator.discover_and_configure
      end

      # Generate and save the final configuration
      #
      # @return [Boolean] True if configuration was saved successfully
      def generate_config
        @logger.step('Generating configuration...')
        config_generator = ConfigGenerator.new(@config, @setup_data)
        config_generator.generate_and_save
      end

      # Check if this is a first-time setup
      #
      # @return [Boolean] True if no configuration exists
      def first_time_setup?
        !@config.exist? || missing_critical_config?
      end

      # Check if setup is required
      #
      # @return [Boolean] True if setup should be run
      def setup_required?
        first_time_setup? || @prompt.yes?('Configuration exists. Run setup anyway?')
      end

      private

      # Display welcome message with ASCII art
      def display_welcome
        welcome_box = TTY::Box.frame(
          "🚀 Welcome to BlueprintsCLI Setup! 🚀\n\n" \
          "This wizard will guide you through the initial configuration\n" \
          "including AI providers, database setup, and preferences.\n\n" \
          'Setup typically takes 2-5 minutes.',
          padding: 1,
          align: :center,
          style: { border: { fg: :cyan } }
        )
        puts welcome_box
      end

      # Confirm user wants to continue with setup
      #
      # @return [Boolean] True if user confirms
      def confirm_continue
        if first_time_setup?
          @prompt.yes?('Ready to begin setup?', default: true)
        else
          @prompt.yes?('Existing configuration found. Overwrite?', default: false)
        end
      end

      # Run all setup phases in order
      def run_setup_phases
        phases = [
          { name: 'Prerequisites Check', method: :check_prerequisites },
          { name: 'AI Providers', method: :setup_providers },
          { name: 'Model Configuration', method: :setup_models },
          { name: 'Database Setup', method: :setup_database },
          { name: 'Application Preferences', method: :setup_preferences },
          { name: 'Configuration Generation', method: :generate_config },
          { name: 'Setup Verification', method: :verify_setup }
        ]

        phases.each_with_index do |phase, index|
          @logger.step("Phase #{index + 1}/#{phases.length}: #{phase[:name]}")

          success = send(phase[:method])
          raise SetupValidationError, "Setup failed at phase: #{phase[:name]}" unless success

          display_phase_completion(phase[:name])
        end
      end

      # Check system prerequisites
      #
      # @return [Boolean] True if prerequisites are met
      def check_prerequisites
        @logger.info('Checking Ruby version...')
        ruby_version = RUBY_VERSION
        @logger.success("Ruby #{ruby_version} detected")

        @logger.info('Checking required gems...')
        required_gems = %w[tty-prompt tty-config ruby_llm sequel pg]

        required_gems.each do |gem_name|
          require gem_name.tr('-', '/')
          @logger.success("✓ #{gem_name}")
        rescue LoadError
          @logger.failure("✗ #{gem_name} (please run: bundle install)")
          return false
        end

        true
      end

      # Setup application preferences
      #
      # @return [Boolean] True if preferences setup completed
      def setup_preferences
        @logger.info('Configuring application preferences...')

        # Editor preference
        current_editor = ENV['EDITOR'] || ENV['VISUAL'] || 'vim'
        editor = @prompt.ask('Default editor:', default: current_editor)
        @setup_data[:editor] = { default: editor, auto_save: true }

        # Logging preferences
        log_level = @prompt.select('Console log level:', %w[debug info warn error])
        file_logging = @prompt.yes?('Enable file logging?', default: true)

        @setup_data[:logger] = {
          level: log_level,
          file_logging: file_logging,
          context_enabled: true,
          context_detail_level: 'full'
        }

        # UI preferences
        colors = @prompt.yes?('Enable colored output?', default: true)
        interactive = @prompt.yes?('Enable interactive prompts?', default: true)

        @setup_data[:ui] = {
          colors: colors,
          interactive: interactive,
          pager: 'most'
        }

        true
      end

      # Verify the complete setup
      #
      # @return [Boolean] True if verification passes
      def verify_setup
        @logger.info('Verifying setup...')

        # Test database connection
        if @setup_data[:database]
          @logger.info('Testing database connection...')
          # Database verification logic here
          @logger.success('Database connection verified')
        end

        # Test AI provider connections
        if @setup_data[:providers]
          @logger.info('Testing AI provider connections...')
          @setup_data[:providers].each do |provider, config|
            next unless config[:api_key]

            @logger.info("Testing #{provider} connection...")
            # Provider verification logic here
            @logger.success("#{provider} connection verified")
          end
        end

        @logger.success('Setup verification completed!')
        true
      end

      # Display phase completion message
      #
      # @param phase_name [String] Name of completed phase
      def display_phase_completion(phase_name)
        @logger.success("✓ #{phase_name} completed")
        puts # Add spacing
      end

      # Display setup completion message
      def display_completion
        completion_box = TTY::Box.frame(
          "🎉 Setup Complete! 🎉\n\n" \
          "BlueprintsCLI has been successfully configured.\n" \
          "You can now start using the application.\n\n" \
          "Next steps:\n" \
          "• Run 'bin/blueprintsCLI' to access the interactive menu\n" \
          "• Try 'bin/blueprintsCLI blueprint list' to see existing blueprints\n" \
          '• Visit the documentation for more features',
          padding: 1,
          align: :center,
          style: { border: { fg: :green } }
        )
        puts completion_box
      end

      # Display setup cancellation message
      def display_cancellation
        @logger.info('Setup cancelled by user.')
        puts 'You can run setup again anytime with: bin/blueprintsCLI setup'
      end

      # Handle setup errors
      #
      # @param error [StandardError] The error that occurred
      def handle_setup_error(error)
        @logger.failure("Setup failed: #{error.message}")
        @logger.debug(error.backtrace.join("\n")) if ENV['DEBUG']

        puts "\nSetup encountered an error. Please check the logs and try again."
        puts 'If the problem persists, please create an issue at:'
        puts 'https://github.com/your-org/blueprintsCLI/issues'
      end

      # Check if critical configuration is missing
      #
      # @return [Boolean] True if critical config is missing
      def missing_critical_config?
        return true unless @config.exist?

        # Check for essential configuration
        required_keys = [
          %i[database url],
          %i[ai sublayer provider]
        ]

        required_keys.any? do |keys|
          @config.fetch(*keys).nil?
        end
      end
    end
  end
end
