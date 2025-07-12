# frozen_string_literal: true

require_relative '../configuration'

module BlueprintsCLI
  module Actions
    # Manages the application's configuration through a command-line interface.
    # This action allows users to show, set up, test, and reset the configuration
    # using the new TTY::Config-based BlueprintsCLI::Configuration system.
    # Handles settings for the database, AI providers, logger, and various feature flags.
    #
    # @example Show the current configuration
    #   BlueprintsCLI::Actions::Config.new(subcommand: 'show').call
    #
    # @example Run the interactive setup
    #   BlueprintsCLI::Actions::Config.new(subcommand: 'setup').call
    class Config < Sublayer::Actions::Base

      ##
      # Initializes the configuration action.
      #
      # @param subcommand [String] The configuration command to execute.
      #   Defaults to 'show'. Supported values: 'show', 'view', 'setup',
      #   'init', 'edit', 'test', 'validate', 'reset'.
      def initialize(subcommand: 'show')
        @subcommand = subcommand
        @config = BlueprintsCLI::Configuration.new
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
        when 'test', 'validate'
          test_configuration
        when 'reset'
          reset_configuration
        when 'migrate'
          migrate_configuration
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
        BlueprintsCLI.logger.step('Blueprint Configuration')
        puts '=' * 60
        puts "Config file: #{@config.config_file_path || 'Not found'}"
        puts "File exists: #{@config.exist? ? 'Yes' : 'No'}"
        puts ''

        if @config.exist? || @config.to_hash.any?
          # Database Configuration
          puts 'Database Configuration:'.colorize(:cyan)
          puts "  URL: #{mask_password(@config.database_url || 'Not set')}"
          puts ''

          # AI Configuration - Sublayer
          puts 'AI Configuration (Sublayer):'.colorize(:cyan)
          puts "  Provider: #{@config.fetch(:ai, :sublayer, :provider, default: 'Not set')}"
          puts "  Model: #{@config.fetch(:ai, :sublayer, :model, default: 'Not set')}"
          sublayer_provider = @config.fetch(:ai, :sublayer, :provider, default: '').downcase
          api_key_status = @config.ai_api_key(sublayer_provider) ? 'Set' : 'Not set'
          puts "  API Key: #{api_key_status}"
          puts "  Embedding Model: #{@config.fetch(:ai, :embedding_model, default: 'Not set')}"
          puts ''

          # AI Configuration - Ruby LLM
          puts 'AI Configuration (Ruby LLM):'.colorize(:cyan)
          ruby_llm_config = @config.ruby_llm_config
          if ruby_llm_config.any?
            ruby_llm_config.each do |key, value|
              next if key.to_s.end_with?('_api_key')
              puts "  #{key}: #{value}"
            end
            puts "  Available API Keys: #{ruby_llm_config.keys.select { |k| k.to_s.end_with?('_api_key') }.join(', ')}"
          else
            puts '  No Ruby LLM configuration found'
          end
          puts ''

          # Editor Configuration
          puts 'Editor Configuration:'.colorize(:cyan)
          puts "  Editor: #{@config.fetch(:blueprints, :editor, default: 'Not set')}"
          puts "  Auto-save: #{@config.fetch(:blueprints, :auto_save_edits, default: 'Not set')}"
          puts ''

          # Feature Flags
          puts 'Feature Flags:'.colorize(:cyan)
          puts "  Auto-description: #{@config.fetch(:blueprints, :features, :auto_description, default: 'Not set')}"
          puts "  Auto-categorization: #{@config.fetch(:blueprints, :features, :auto_categorize, default: 'Not set')}"
          puts "  Improvement analysis: #{@config.fetch(:blueprints, :features, :improvement_analysis, default: 'Not set')}"
          puts ''

          # Logger Configuration
          puts 'Logger Configuration:'.colorize(:cyan)
          puts "  Level: #{@config.fetch(:logger, :level, default: 'Not set')}"
          puts "  File logging: #{@config.fetch(:logger, :file_logging, default: 'Not set')}"
          puts "  File path: #{@config.fetch(:logger, :file_path, default: 'Not set')}"
          puts ''

          # Search Configuration
          puts 'Search Configuration:'.colorize(:cyan)
          puts "  Default limit: #{@config.fetch(:blueprints, :search, :default_limit, default: 'Not set')}"
          puts "  Semantic search: #{@config.fetch(:blueprints, :search, :semantic_search, default: 'Not set')}"
          puts ''

          # Performance Configuration
          puts 'Performance Configuration:'.colorize(:cyan)
          puts "  Batch size: #{@config.fetch(:blueprints, :performance, :batch_size, default: 'Not set')}"
          puts "  Connection pool size: #{@config.fetch(:blueprints, :performance, :connection_pool_size, default: 'Not set')}"
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
        current_editor = @config.fetch(:blueprints, :editor, default: ENV['EDITOR'] || ENV['VISUAL'] || 'vim')
        editor = prompt_for_input('Preferred editor', current_editor)
        @config.set(:blueprints, :editor, value: editor)

        current_auto_save = @config.fetch(:blueprints, :auto_save_edits, default: false)
        auto_save = prompt_for_boolean('Auto-save edits', current_auto_save)
        @config.set(:blueprints, :auto_save_edits, value: auto_save)

        # Feature flags
        puts "\n🎛️  Feature Configuration".colorize(:cyan)
        current_auto_desc = @config.fetch(:blueprints, :features, :auto_description, default: true)
        auto_desc = prompt_for_boolean('Auto-generate descriptions', current_auto_desc)
        @config.set(:blueprints, :features, :auto_description, value: auto_desc)

        current_auto_cat = @config.fetch(:blueprints, :features, :auto_categorize, default: true)
        auto_cat = prompt_for_boolean('Auto-generate categories', current_auto_cat)
        @config.set(:blueprints, :features, :auto_categorize, value: auto_cat)

        current_improvement = @config.fetch(:blueprints, :features, :improvement_analysis, default: true)
        improvement = prompt_for_boolean('Enable AI improvement analysis', current_improvement)
        @config.set(:blueprints, :features, :improvement_analysis, value: improvement)

        # Logger configuration
        puts "\n📝 Logger Configuration".colorize(:cyan)
        current_level = @config.fetch(:logger, :level, default: 'info')
        log_level = prompt_for_choice('Log level', %w[debug info warn error fatal], current_level)
        @config.set(:logger, :level, value: log_level)

        current_file_logging = @config.fetch(:logger, :file_logging, default: false)
        file_logging = prompt_for_boolean('Enable file logging', current_file_logging)
        @config.set(:logger, :file_logging, value: file_logging)

        if file_logging
          current_file_path = @config.fetch(:logger, :file_path, default: @config.send(:default_log_path))
          file_path = prompt_for_input('Log file path', current_file_path)
          @config.set(:logger, :file_path, value: file_path)
        end

        # Save configuration
        puts "\n💾 Saving Configuration".colorize(:blue)
        save_success = @config.write(force: true, create: true)

        if save_success
          BlueprintsCLI.logger.success('Configuration saved successfully!', file: @config.config_file_path)
          BlueprintsCLI.logger.tip("Run 'blueprint config test' to validate the configuration")
        else
          BlueprintsCLI.logger.failure('Failed to save configuration')
        end

        save_success
      end

      ##
      # Tests the validity and connectivity of the current configuration.
      #
      # Validates configuration structure and tests connectivity to database,
      # AI providers, and editor availability.
      #
      # @return [Boolean] Returns `true` if all tests pass, `false` otherwise.
      def test_configuration
        BlueprintsCLI.logger.step('Testing Blueprint Configuration')
        puts '=' * 50

        all_tests_passed = true

        # Test configuration validation
        puts "\n📋 Validating configuration structure...".colorize(:cyan)
        begin
          @config.validate!
          BlueprintsCLI.logger.success('Configuration structure is valid')
        rescue BlueprintsCLI::Configuration::ValidationError => e
          BlueprintsCLI.logger.failure("Configuration validation failed: #{e.message}")
          all_tests_passed = false
        end

        # Test database connection
        puts "\n📊 Testing database connection...".colorize(:cyan)
        db_success = test_database_connection
        all_tests_passed &&= db_success

        # Test AI API connections
        puts "\n🤖 Testing AI API connections...".colorize(:cyan)
        ai_success = test_ai_connections
        all_tests_passed &&= ai_success

        # Test editor
        puts "\n✏️  Testing editor availability...".colorize(:cyan)
        editor_success = test_editor
        all_tests_passed &&= editor_success

        # Test logger configuration
        puts "\n📝 Testing logger configuration...".colorize(:cyan)
        logger_success = test_logger_config
        all_tests_passed &&= logger_success

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
      # Prompts the user for confirmation before deleting the configuration file.
      #
      # @return [Boolean] Returns `true` if the file is deleted or if it didn't
      #   exist initially. Returns `false` if the user cancels the operation.
      def reset_configuration
        config_file = @config.config_file_path
        
        if config_file && File.exist?(config_file)
          print '⚠️  This will delete the existing configuration. Continue? (y/N): '
          response = STDIN.gets.chomp.downcase

          if %w[y yes].include?(response)
            File.delete(config_file)
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
      # Migrate existing configuration files to new format
      #
      # @return [Boolean] Returns `true` if migration succeeded
      def migrate_configuration
        BlueprintsCLI.logger.step('Migrating Configuration Files')
        puts '=' * 50
        puts ''

        # Check for existing config files
        old_config_path = File.join(__dir__, '..', 'config', 'blueprints.yml')
        old_sublayer_path = File.join(__dir__, '..', 'config', 'sublayer.yml')
        
        migrated_any = false

        # Migrate old blueprints.yml
        if File.exist?(old_config_path)
          puts "📄 Found existing blueprints.yml configuration"
          begin
            old_config = YAML.load_file(old_config_path)
            migrate_blueprints_config(old_config)
            migrated_any = true
            puts "✅ Migrated blueprints.yml configuration"
          rescue StandardError => e
            BlueprintsCLI.logger.failure("Failed to migrate blueprints.yml: #{e.message}")
          end
        end

        # Migrate old sublayer.yml
        if File.exist?(old_sublayer_path)
          puts "📄 Found existing sublayer.yml configuration"
          begin
            old_sublayer = YAML.load_file(old_sublayer_path)
            migrate_sublayer_config(old_sublayer)
            migrated_any = true
            puts "✅ Migrated sublayer.yml configuration"
          rescue StandardError => e
            BlueprintsCLI.logger.failure("Failed to migrate sublayer.yml: #{e.message}")
          end
        end

        if migrated_any
          # Save the migrated configuration
          if @config.write(force: true, create: true)
            BlueprintsCLI.logger.success('Migration completed successfully!', file: @config.config_file_path)
            puts "\n💡 You can now delete the old configuration files:"
            puts "   rm #{old_config_path}" if File.exist?(old_config_path)
            puts "   rm #{old_sublayer_path}" if File.exist?(old_sublayer_path)
          else
            BlueprintsCLI.logger.failure('Failed to save migrated configuration')
            return false
          end
        else
          puts "ℹ️  No existing configuration files found to migrate"
        end

        true
      end

      ##
      # Displays help text for the configuration command.
      # @return [nil]
      def show_config_help
        puts <<~HELP
          Blueprint Configuration Commands:

          blueprint config show      Show current configuration
          blueprint config setup     Interactive configuration setup  
          blueprint config test      Test configuration connectivity and validation
          blueprint config migrate   Migrate old configuration files to new format
          blueprint config reset     Reset configuration to defaults

          Configuration is managed by TTY::Config and stored in:
          #{@config.config_file_path || '~/.config/BlueprintsCLI/config.yml'}
        HELP
      end

      ##
      # Migrate old blueprints.yml configuration to new format
      #
      # @param old_config [Hash] The old configuration hash
      def migrate_blueprints_config(old_config)
        # Database configuration
        if old_config['database']
          @config.set(:blueprints, :database, :url, value: old_config['database']['url']) if old_config['database']['url']
        end

        # Editor configuration
        @config.set(:blueprints, :editor, value: old_config['editor']) if old_config['editor']
        @config.set(:blueprints, :auto_save_edits, value: old_config['auto_save_edits']) if old_config.key?('auto_save_edits')

        # Feature flags
        if old_config['features']
          @config.set(:blueprints, :features, :auto_description, value: old_config['features']['auto_description']) if old_config['features'].key?('auto_description')
          @config.set(:blueprints, :features, :auto_categorize, value: old_config['features']['auto_categorize']) if old_config['features'].key?('auto_categorize')
          @config.set(:blueprints, :features, :improvement_analysis, value: old_config['features']['improvement_analysis']) if old_config['features'].key?('improvement_analysis')
        end

        # Search configuration
        if old_config['search']
          @config.set(:blueprints, :search, :default_limit, value: old_config['search']['default_limit']) if old_config['search']['default_limit']
          @config.set(:blueprints, :search, :semantic_search, value: old_config['search']['semantic_search']) if old_config['search'].key?('semantic_search')
        end

        # Performance configuration
        if old_config['performance']
          @config.set(:blueprints, :performance, :batch_size, value: old_config['performance']['batch_size']) if old_config['performance']['batch_size']
          @config.set(:blueprints, :performance, :connection_pool_size, value: old_config['performance']['connection_pool_size']) if old_config['performance']['connection_pool_size']
        end

        # AI configuration (if present in old format)
        if old_config['ai']
          @config.set(:ai, :sublayer, :provider, value: old_config['ai']['provider']) if old_config['ai']['provider']
          @config.set(:ai, :sublayer, :model, value: old_config['ai']['model']) if old_config['ai']['model']
        end
      end

      ##
      # Migrate old sublayer.yml configuration to new format
      #
      # @param old_sublayer [Hash] The old sublayer configuration hash
      def migrate_sublayer_config(old_sublayer)
        @config.set(:ai, :sublayer, :project_name, value: old_sublayer[:project_name]) if old_sublayer[:project_name]
        @config.set(:ai, :sublayer, :project_template, value: old_sublayer[:project_template]) if old_sublayer[:project_template]
        @config.set(:ai, :sublayer, :provider, value: old_sublayer[:ai_provider]) if old_sublayer[:ai_provider]
        @config.set(:ai, :sublayer, :model, value: old_sublayer[:ai_model]) if old_sublayer[:ai_model]
      end

      ##
      # Displays the status of relevant environment variables.
      # @return [void]
      def show_environment_variables
        puts '🌍 Environment Variables:'.colorize(:blue)

        env_vars = {
          'GEMINI_API_KEY' => ENV.fetch('GEMINI_API_KEY', nil),
          'GOOGLE_API_KEY' => ENV.fetch('GOOGLE_API_KEY', nil),
          'OPENAI_API_KEY' => ENV.fetch('OPENAI_API_KEY', nil),
          'ANTHROPIC_API_KEY' => ENV.fetch('ANTHROPIC_API_KEY', nil),
          'DEEPSEEK_API_KEY' => ENV.fetch('DEEPSEEK_API_KEY', nil),
          'BLUEPRINT_DATABASE_URL' => ENV.fetch('BLUEPRINT_DATABASE_URL', nil),
          'DATABASE_URL' => ENV.fetch('DATABASE_URL', nil),
          'BLUEPRINTS_DEBUG' => ENV.fetch('BLUEPRINTS_DEBUG', nil),
          'DEBUG' => ENV.fetch('DEBUG', nil),
          'EDITOR' => ENV.fetch('EDITOR', nil),
          'VISUAL' => ENV.fetch('VISUAL', nil)
        }

        env_vars.each do |key, value|
          status = value ? (key.include?('KEY') ? 'Set (hidden)' : value) : 'Not set'
          puts "  #{key}: #{status}"
        end
        puts ''
      end

      ##
      # Tests the database connection using the URL from the configuration.
      #
      # @return [Boolean] `true` if the connection is successful, `false` otherwise.
      def test_database_connection
        require 'sequel'
        db_url = @config.database_url
        
        if db_url.nil? || db_url.empty?
          BlueprintsCLI.logger.failure('No database URL configured')
          return false
        end
        
        db = Sequel.connect(db_url)
        db.test_connection
        BlueprintsCLI.logger.success('Database connection successful')
        true
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Database connection failed: #{e.message}")
        false
      end

      ##
      # Tests the AI provider connections by checking for API keys.
      #
      # Tests both Sublayer and Ruby LLM configurations.
      #
      # @return [Boolean] `true` if at least one API key is found, `false` otherwise.
      def test_ai_connections
        success_count = 0
        total_tests = 0
        
        # Test Sublayer configuration
        sublayer_provider = @config.fetch(:ai, :sublayer, :provider, default: '').downcase
        if !sublayer_provider.empty?
          total_tests += 1
          api_key = @config.ai_api_key(sublayer_provider)
          if api_key
            BlueprintsCLI.logger.success("Sublayer AI API key found for #{sublayer_provider}")
            success_count += 1
          else
            BlueprintsCLI.logger.failure("Sublayer AI API key not found for #{sublayer_provider}")
          end
        end
        
        # Test Ruby LLM configuration
        ruby_llm_config = @config.ruby_llm_config
        api_keys = ruby_llm_config.select { |k, v| k.to_s.end_with?('_api_key') && v }
        
        if api_keys.any?
          api_keys.each do |key, _|
            provider = key.to_s.gsub('_api_key', '')
            BlueprintsCLI.logger.success("Ruby LLM API key found for #{provider}")
            success_count += 1
            total_tests += 1
          end
        else
          BlueprintsCLI.logger.warn('No Ruby LLM API keys configured')
        end
        
        if total_tests == 0
          BlueprintsCLI.logger.warn('No AI providers configured')
          false
        else
          success_count > 0
        end
      end

      ##
      # Tests if the configured editor is available in the system's PATH.
      #
      # @return [Boolean] `true` if the editor command is found, `false` otherwise.
      def test_editor
        editor = @config.fetch(:blueprints, :editor, default: 'vim')
        
        if editor.nil? || editor.empty?
          BlueprintsCLI.logger.failure('No editor configured')
          return false
        end
        
        if system("which #{editor} > /dev/null 2>&1")
          BlueprintsCLI.logger.success("Editor '#{editor}' found")
          true
        else
          BlueprintsCLI.logger.failure("Editor '#{editor}' not found")
          false
        end
      end
      
      ##
      # Tests the logger configuration.
      #
      # @return [Boolean] `true` if logger config is valid, `false` otherwise.
      def test_logger_config
        level = @config.fetch(:logger, :level, default: 'info')
        valid_levels = %w[debug info warn error fatal]
        
        unless valid_levels.include?(level.to_s.downcase)
          BlueprintsCLI.logger.failure("Invalid logger level: #{level}")
          return false
        end
        
        if @config.fetch(:logger, :file_logging, default: false)
          file_path = @config.fetch(:logger, :file_path)
          if file_path.nil? || file_path.empty?
            BlueprintsCLI.logger.failure('File logging enabled but no file path configured')
            return false
          end
          
          # Check if directory is writable
          dir = File.dirname(File.expand_path(file_path))
          unless File.directory?(dir) || File.writable?(File.dirname(dir))
            BlueprintsCLI.logger.failure("Log directory not writable: #{dir}")
            return false
          end
        end
        
        BlueprintsCLI.logger.success('Logger configuration is valid')
        true
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Logger configuration test failed: #{e.message}")
        false
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
