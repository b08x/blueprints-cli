# frozen_string_literal: true

module BlueprintsCLI
  module Actions
    # Manages the application's configuration through a command-line interface.
    # This action allows users to show, set up, test, and reset the configuration,
    # which is stored in a YAML file. It handles settings for the database,
    # AI provider, editor, and various feature flags.
    #
    # @example Show the current configuration
    #   BlueprintsCLI::Actions::Config.new(subcommand: 'show').call
    #
    # @example Run the interactive setup
    #   BlueprintsCLI::Actions::Config.new(subcommand: 'setup').call
    class Config < Sublayer::Actions::Base
      # The path to the YAML file where configuration is stored.
      CONFIG_PATH = File.join(__dir__, '..', 'config', 'blueprints.yml')

      ##
      # Initializes the configuration action.
      #
      # @param subcommand [String] The configuration command to execute.
      #   Defaults to 'show'. Supported values: 'show', 'view', 'setup',
      #   'init', 'edit', 'test', 'reset'.
      def initialize(subcommand: 'show')
        @subcommand = subcommand
      end

      ##
      # Executes the specified configuration subcommand.
      #
      # This is the main entry point for the action. It routes to the appropriate
      # method based on the subcommand provided during initialization. It also
      # includes error handling to catch and report issues during execution.
      #
      # @return [Boolean] Returns `true` on success and `false` on failure or
      #   if an unknown subcommand is provided.
      def call
        case @subcommand
        when 'show', 'view'
          show_configuration
        when 'setup', 'init', 'edit'
          setup_configuration
        when 'test'
          test_configuration
        when 'reset'
          reset_configuration
        else
          BlueprintsCLI.logger.failure("Unknown config subcommand: '#{@subcommand}'")
          show_config_help
          false
        end
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error managing configuration: #{e.message}")
        BlueprintsCLI.logger.debug(e) # tty-logger will format the exception and backtrace
        false
      end

      private

      ##
      # Displays the current configuration settings.
      #
      # Reads from the configuration file and prints a formatted summary of all
      # settings, including database, AI, editor, and feature flags. Also shows
      # the status of relevant environment variables.
      #
      # @return [Boolean] Returns `true`.
      def show_configuration
        config = load_configuration

        BlueprintsCLI.logger.step('Blueprint Configuration')
        puts '=' * 60
        puts "Config file: #{CONFIG_PATH}"
        puts "File exists: #{File.exist?(CONFIG_PATH) ? 'Yes' : 'No'}"
        puts ''

        if config
          puts 'Database Configuration:'.colorize(:cyan)
          puts "  URL: #{mask_password(config.dig('database', 'url') || 'Not set')}"
          puts ''

          puts 'AI Configuration:'.colorize(:cyan)
          puts "  Provider: #{config.dig('ai', 'provider') || 'Not set'}"
          puts "  Model: #{config.dig('ai', 'model') || 'Not set'}"
          puts "  API Key: #{config.dig('ai', 'api_key') ? 'Set' : 'Not set'}"
          puts ''

          puts 'Editor Configuration:'.colorize(:cyan)
          puts "  Editor: #{config.dig('editor') || 'Not set'}"
          puts "  Auto-save: #{config.dig('auto_save_edits') || 'Not set'}"
          puts ''

          puts 'Feature Flags:'.colorize(:cyan)
          puts "  Auto-description: #{config.dig('features', 'auto_description') || 'Not set'}"
          puts "  Auto-categorization: #{config.dig('features', 'auto_categorize') || 'Not set'}"
          puts "  Debug mode: #{config.dig('debug') || 'Not set'}"
        else
          BlueprintsCLI.logger.failure('No configuration found')
          BlueprintsCLI.logger.tip("Run 'blueprint config setup' to create configuration")
        end

        puts '=' * 60
        puts ''

        # Show environment variables
        show_environment_variables

        true
      end

      ##
      # Runs an interactive setup process for configuration.
      #
      # Prompts the user for all necessary configuration values, such as database
      # URL, AI provider/model, and editor preferences. It then saves the
      # resulting configuration to the YAML file.
      #
      # @return [Boolean] Returns `true` if the configuration is saved
      #   successfully, `false` otherwise.
      def setup_configuration
        BlueprintsCLI.logger.step('Blueprint Configuration Setup')
        puts '=' * 50
        puts ''

        config = load_configuration || {}

        # Database configuration
        puts '📊 Database Configuration'.colorize(:cyan)
        current_db = config.dig('database', 'url') || 'postgres://localhost/blueprints_development'
        db_url = prompt_for_input('Database URL', current_db)

        config['database'] = { 'url' => db_url }

        # AI configuration
        puts "\n🤖 AI Configuration".colorize(:cyan)
        current_provider = config.dig('ai', 'provider') || 'gemini'
        provider = prompt_for_choice('AI Provider', %w[gemini openai], current_provider)

        current_model = config.dig('ai',
                                   'model') || (provider == 'gemini' ? 'text-embedding-004' : 'text-embedding-3-small')
        model = prompt_for_input('AI Model', current_model)

        puts '💡 Set API key via environment variable:'.colorize(:yellow)
        puts '   export GEMINI_API_KEY=your_key_here' if provider == 'gemini'
        puts '   export OPENAI_API_KEY=your_key_here' if provider == 'openai'

        config['ai'] = {
          'provider' => provider,
          'model' => model
        }

        # Editor configuration
        puts "\n✏️  Editor Configuration".colorize(:cyan)
        current_editor = config.dig('editor') || ENV['EDITOR'] || ENV['VISUAL'] || 'vim'
        editor = prompt_for_input('Preferred editor', current_editor)

        current_auto_save = config.dig('auto_save_edits')
        auto_save = prompt_for_boolean('Auto-save edits', current_auto_save.nil? || current_auto_save)

        config['editor'] = editor
        config['auto_save_edits'] = auto_save

        # Feature flags
        puts "\n🎛️  Feature Configuration".colorize(:cyan)
        current_auto_desc = config.dig('features', 'auto_description')
        auto_desc = prompt_for_boolean('Auto-generate descriptions', current_auto_desc.nil? || current_auto_desc)

        current_auto_cat = config.dig('features', 'auto_categorize')
        auto_cat = prompt_for_boolean('Auto-generate categories', current_auto_cat.nil? || current_auto_cat)

        current_debug = config.dig('debug')
        debug = prompt_for_boolean('Debug mode', current_debug || false)

        config['features'] = {
          'auto_description' => auto_desc,
          'auto_categorize' => auto_cat
        }
        config['debug'] = debug

        # Save configuration
        puts "\n💾 Saving Configuration".colorize(:blue)
        save_success = save_configuration(config)

        if save_success
          BlueprintsCLI.logger.success('Configuration saved successfully!', file: CONFIG_PATH)
          BlueprintsCLI.logger.tip("Run 'blueprint config test' to validate the configuration")
        else
          BlueprintsCLI.logger.failure('Failed to save configuration')
        end

        save_success
      end

      ##
      # Tests the validity and connectivity of the current configuration.
      #
      # Checks the database connection, AI provider API key, and editor
      # availability based on the settings in the configuration file.
      #
      # @return [Boolean] Returns `true` if all tests pass, `false` otherwise.
      def test_configuration
        BlueprintsCLI.logger.step('Testing Blueprint Configuration')
        puts '=' * 50

        config = load_configuration
        unless config
          BlueprintsCLI.logger.failure('No configuration found')
          return false
        end

        all_tests_passed = true

        # Test database connection
        puts "\n📊 Testing database connection...".colorize(:cyan)
        db_success = test_database_connection(config)
        all_tests_passed &&= db_success

        # Test AI API
        puts "\n🤖 Testing AI API connection...".colorize(:cyan)
        ai_success = test_ai_connection(config)
        all_tests_passed &&= ai_success

        # Test editor
        puts "\n✏️  Testing editor availability...".colorize(:cyan)
        editor_success = test_editor(config)
        all_tests_passed &&= editor_success

        puts "\n" + ('=' * 50)
        if all_tests_passed
          BlueprintsCLI.logger.success('All configuration tests passed!')
        else
          BlueprintsCLI.logger.failure('Some configuration tests failed')
          BlueprintsCLI.logger.tip("Run 'blueprint config setup' to fix issues")
        end

        all_tests_passed
      end

      ##
      # Deletes the configuration file, resetting to defaults.
      #
      # Prompts the user for confirmation before deleting the `blueprints.yml` file.
      #
      # @return [Boolean] Returns `true` if the file is deleted or if it didn't
      #   exist initially. Returns `false` if the user cancels the operation.
      def reset_configuration
        if File.exist?(CONFIG_PATH)
          print '⚠️  This will delete the existing configuration. Continue? (y/N): '
          response = STDIN.gets.chomp.downcase

          if %w[y yes].include?(response)
            File.delete(CONFIG_PATH)
            BlueprintsCLI.logger.success('Configuration reset successfully')
            BlueprintsCLI.logger.tip("Run 'blueprint config setup' to create new configuration")
            true
          else
            BlueprintsCLI.logger.warn('Reset cancelled')
            false
          end
        else
          BlueprintsCLI.logger.info('No configuration file found to reset')
          true
        end
      end

      ##
      # Displays help text for the configuration command.
      # @return [nil]
      def show_config_help
        puts <<~HELP
          Blueprint Configuration Commands:

          blueprint config show     Show current configuration
          blueprint config setup    Interactive configuration setup
          blueprint config test     Test configuration connectivity
          blueprint config reset    Reset configuration to defaults

          Configuration is stored in: #{CONFIG_PATH}
        HELP
      end

      ##
      # Loads the configuration from the YAML file.
      #
      # @return [Hash, nil] A hash containing the configuration, or `nil` if the
      #   file does not exist or an error occurs during loading.
      def load_configuration
        return nil unless File.exist?(CONFIG_PATH)

        YAML.load_file(CONFIG_PATH)
      rescue StandardError => e
        BlueprintsCLI.logger.warn("Error loading configuration: #{e.message}")
        nil
      end

      ##
      # Saves the given configuration hash to the YAML file.
      #
      # Ensures the directory exists before writing the file.
      #
      # @param config [Hash] The configuration hash to save.
      # @return [Boolean] `true` on successful save, `false` otherwise.
      def save_configuration(config)
        # Ensure directory exists
        config_dir = File.dirname(CONFIG_PATH)
        FileUtils.mkdir_p(config_dir) unless Dir.exist?(config_dir)

        File.write(CONFIG_PATH, config.to_yaml)
        true
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error saving configuration: #{e.message}")
        false
      end

      ##
      # Displays the status of relevant environment variables.
      # @return [void]
      def show_environment_variables
        puts '🌍 Environment Variables:'.colorize(:blue)

        env_vars = {
          'GEMINI_API_KEY' => ENV.fetch('GEMINI_API_KEY', nil),
          'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', nil),
          'BLUEPRINT_DATABASE_URL' => ENV.fetch('BLUEPRINT_DATABASE_URL', nil),
          'DATABASE_URL' => ENV.fetch('DATABASE_URL', nil),
          'EDITOR' => ENV.fetch('EDITOR', nil),
          'VISUAL' => ENV.fetch('VISUAL', nil)
        }

        env_vars.each do |key, value|
          status = value ? 'Set' : 'Not set'
          puts "  #{key}: #{status}"
        end
        puts ''
      end

      ##
      # Tests the database connection using the URL from the configuration.
      #
      # @param config [Hash] The loaded configuration hash.
      # @return [Boolean] `true` if the connection is successful, `false` otherwise.
      def test_database_connection(config)
        require 'sequel'
        db_url = config.dig('database', 'url')
        db = Sequel.connect(db_url)
        db.test_connection
        BlueprintsCLI.logger.success('Database connection successful')
        true
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Database connection failed: #{e.message}")
        false
      end

      ##
      # Tests the AI provider connection by checking for an API key.
      #
      # This is a simplified test that only checks if the relevant environment
      # variable for the configured provider is set.
      #
      # @param config [Hash] The loaded configuration hash.
      # @return [Boolean] `true` if the API key is found, `false` otherwise.
      def test_ai_connection(config)
        # This is a simplified test - in reality you'd make an actual API call
        provider = config.dig('ai', 'provider')
        api_key = case provider
                  when 'gemini'
                    ENV.fetch('GEMINI_API_KEY', nil)
                  when 'openai'
                    ENV.fetch('OPENAI_API_KEY', nil)
                  end

        if api_key
          BlueprintsCLI.logger.success("AI API key found for #{provider}")
          true
        else
          BlueprintsCLI.logger.failure("AI API key not found for #{provider}")
          false
        end
      end

      ##
      # Tests if the configured editor is available in the system's PATH.
      #
      # @param config [Hash] The loaded configuration hash.
      # @return [Boolean] `true` if the editor command is found, `false` otherwise.
      def test_editor(config)
        editor = config.dig('editor')
        if system("which #{editor} > /dev/null 2>&1")
          BlueprintsCLI.logger.success("Editor '#{editor}' found")
          true
        else
          BlueprintsCLI.logger.failure("Editor '#{editor}' not found")
          false
        end
      end

      ##
      # Prompts the user for text input via STDIN.
      #
      # @param prompt [String] The message to display to the user.
      # @param default [String, nil] The default value to use if the user enters nothing.
      # @return [String] The user's input or the default value.
      def prompt_for_input(prompt, default = nil)
        print "#{prompt}"
        print " [#{default}]" if default
        print ': '

        input = STDIN.gets.chomp
        input.empty? ? default : input
      end

      ##
      # Prompts the user to select from a list of choices.
      #
      # @param prompt [String] The message to display to the user.
      # @param choices [Array<String>] A list of available options.
      # @param default [String, nil] The default choice if the user enters nothing.
      # @return [String] The user's selection or the default value.
      def prompt_for_choice(prompt, choices, default = nil)
        puts "#{prompt} (#{choices.join('/')})"
        print default ? "[#{default}]: " : ': '

        input = STDIN.gets.chomp
        input.empty? ? default : input
      end

      ##
      # Prompts the user for a boolean (yes/no) response.
      #
      # @param prompt [String] The message to display to the user.
      # @param default [Boolean, nil] The default value (`true`, `false`, or `nil`)
      #   to use if the user enters nothing.
      # @return [Boolean, nil] Returns `true` for 'y', `false` for 'n', or the
      #   default value for any other input.
      def prompt_for_boolean(prompt, default = nil)
        default_text = case default
                       when true then ' [Y/n]'
                       when false then ' [y/N]'
                       else ' [y/n]'
                       end

        print "#{prompt}#{default_text}: "
        input = STDIN.gets.chomp.downcase

        case input
        when 'y', 'yes', 'true'
          true
        when 'n', 'no', 'false'
          false
        else
          default
        end
      end

      ##
      # Masks the password portion of a database URL for safe display.
      #
      # @param url [String] The database URL to process.
      # @return [String] The URL with the password replaced by '***'.
      def mask_password(url)
        return url unless url.include?(':') && url.include?('@')

        url.gsub(/:[^:@]*@/, ':***@')
      end
    end
  end
end
