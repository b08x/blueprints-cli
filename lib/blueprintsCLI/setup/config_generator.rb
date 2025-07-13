# frozen_string_literal: true

require 'yaml'
require 'fileutils'

module BlueprintsCLI
  module Setup
    # ConfigGenerator creates the final configuration file based on setup data.
    # It takes all the collected setup information and generates a comprehensive
    # config.yml file that can be used by the BlueprintsCLI application.
    class ConfigGenerator
      # Configuration template structure
      CONFIG_TEMPLATE = {
        database: {},
        ai: {
          sublayer: {},
          rubyllm: {},
          openai: { log_errors: true }
        },
        logger: {},
        editor: {},
        ui: {},
        features: {
          auto_description: true,
          auto_categorize: true,
          improvement_analysis: true
        },
        search: {
          default_limit: 10,
          semantic_search: true,
          text_search_fallback: true
        },
        export: {
          include_metadata: false,
          auto_detect_extension: true
        },
        performance: {
          batch_size: 100,
          connection_pool_size: 5
        }
      }.freeze

      # Initialize the config generator
      #
      # @param config [BlueprintsCLI::Configuration] Configuration instance
      # @param setup_data [Hash] Setup data collected during wizard
      def initialize(config, setup_data)
        @config = config
        @setup_data = setup_data
        @logger = BlueprintsCLI.logger
        @generated_config = {}
      end

      # Generate and save the configuration
      #
      # @return [Boolean] True if configuration was generated and saved successfully
      def generate_and_save
        @logger.info('Generating configuration file...')

        begin
          build_configuration
          validate_configuration
          backup_existing_config
          save_configuration
          update_environment_instructions

          @logger.success('Configuration file generated successfully!')
          true
        rescue StandardError => e
          @logger.failure("Failed to generate configuration: #{e.message}")
          @logger.debug(e.backtrace.join("\n")) if ENV['DEBUG']
          false
        end
      end

      private

      # Build the complete configuration from setup data
      def build_configuration
        @generated_config = CONFIG_TEMPLATE.dup

        build_database_config
        build_ai_config
        build_logger_config
        build_editor_config
        build_ui_config
        build_performance_config

        @logger.info('Configuration structure built')
      end

      # Build database configuration section
      def build_database_config
        return unless @setup_data[:database]

        @generated_config[:database] = {
          url: @setup_data[:database][:url],
          pool_size: 5
        }

        # Add pgvector-specific settings if available
        if @setup_data[:database][:pgvector_enabled]
          @generated_config[:search][:semantic_search] = true
          @generated_config[:features][:vector_search] = true
        else
          @generated_config[:search][:semantic_search] = false
          @generated_config[:features][:vector_search] = false
        end
      end

      # Build AI configuration section
      def build_ai_config
        build_sublayer_config
        build_rubyllm_config
        build_provider_specific_config
      end

      # Build Sublayer AI configuration
      def build_sublayer_config
        primary_provider = @setup_data[:primary_provider]
        return unless primary_provider

        provider_map = {
          openai: 'OpenAI',
          openrouter: 'OpenAI', # OpenRouter uses OpenAI format
          anthropic: 'Anthropic',
          gemini: 'Gemini',
          deepseek: 'DeepSeek'
        }

        @generated_config[:ai][:sublayer] = {
          provider: provider_map[primary_provider] || 'Gemini',
          model: @setup_data[:models]&.dig(:chat, :id) || 'gemini-2.0-flash',
          project_name: 'BlueprintsCLI',
          template: 'default',
          project_template: 'CLI'
        }
      end

      # Build RubyLLM configuration
      def build_rubyllm_config
        default_model = @setup_data[:models]&.dig(:chat, :id) || 'gemini-2.0-flash'
        embedding_model = @setup_data[:models]&.dig(:embedding, :id) || 'text-embedding-004'

        @generated_config[:ai][:rubyllm] = {
          default_model: default_model,
          default_embedding_model: embedding_model,
          default_image_model: 'imagen-3.0-generate-002',
          request_timeout: 120,
          max_retries: 3,
          retry_interval: 0.5,
          retry_backoff_factor: 2,
          retry_interval_randomness: 0.5,
          log_level: 'info',
          log_assume_model_exists: false
        }

        # Add OpenRouter API base if using OpenRouter
        if @setup_data[:providers]&.key?(:openrouter)
          @generated_config[:ai][:rubyllm][:openai_api_base] = 'https://openrouter.ai/api/v1'
        end

        # Set embedding model from configuration
        @generated_config[:ai][:embedding_model] = embedding_model
      end

      # Build provider-specific configuration
      def build_provider_specific_config
        # Add any provider-specific settings
        if @setup_data[:providers]&.key?(:openai) || @setup_data[:providers]&.key?(:openrouter)
          @generated_config[:ai][:openai] = { log_errors: true }
        end
      end

      # Build logger configuration section
      def build_logger_config
        logger_config = @setup_data[:logger] || {}

        @generated_config[:logger] = {
          level: logger_config[:level] || 'info',
          file_logging: logger_config[:file_logging] || false,
          file_level: logger_config[:file_level] || 'debug',
          file_path: logger_config[:file_path] || default_log_path,
          context_enabled: logger_config[:context_enabled] || true,
          context_detail_level: logger_config[:context_detail_level] || 'full',
          context_cache_size: logger_config[:context_cache_size] || 1000
        }
      end

      # Build editor configuration section
      def build_editor_config
        editor_config = @setup_data[:editor] || {}

        @generated_config[:editor] = {
          default: editor_config[:default] || ENV['EDITOR'] || ENV['VISUAL'] || 'vim',
          auto_save: editor_config[:auto_save] || true,
          temp_dir: editor_config[:temp_dir] || '/tmp'
        }
      end

      # Build UI configuration section
      def build_ui_config
        ui_config = @setup_data[:ui] || {}

        @generated_config[:ui] = {
          colors: ui_config[:colors] || true,
          interactive: ui_config[:interactive] || true,
          pager: ui_config[:pager] || 'most',
          auto_pager: ui_config[:auto_pager] || true
        }
      end

      # Build performance configuration section
      def build_performance_config
        # Use existing performance config or defaults
        @generated_config[:performance] = {
          batch_size: 100,
          connection_pool_size: 5
        }
      end

      # Validate the generated configuration
      def validate_configuration
        @logger.info('Validating configuration...')

        # Check required sections
        required_sections = %i[database ai logger]
        required_sections.each do |section|
          unless @generated_config[section]
            raise StandardError, "Missing required configuration section: #{section}"
          end
        end

        # Validate database URL
        if @generated_config[:database][:url].nil? || @generated_config[:database][:url].empty?
          raise StandardError, 'Database URL is required'
        end

        # Validate AI provider configuration
        unless @generated_config[:ai][:sublayer][:provider]
          raise StandardError, 'AI provider must be specified'
        end

        @logger.success('Configuration validation passed')
      end

      # Backup existing configuration if it exists
      def backup_existing_config
        config_path = @config.config_file_path
        return unless config_path && File.exist?(config_path)

        backup_path = "#{config_path}.backup.#{Time.now.strftime('%Y%m%d_%H%M%S')}"
        FileUtils.cp(config_path, backup_path)
        @logger.info("Existing configuration backed up to: #{backup_path}")
      end

      # Save the configuration to file
      def save_configuration
        # Ensure config directory exists
        config_dir = File.dirname(target_config_path)
        FileUtils.mkdir_p(config_dir)

        # Write configuration file
        File.write(target_config_path, generate_yaml_content)

        @logger.success("Configuration saved to: #{target_config_path}")
      end

      # Generate YAML content with comments
      #
      # @return [String] YAML content with helpful comments
      def generate_yaml_content
        content = "---\n"
        content += "# BlueprintsCLI Configuration\n"
        content += "# Generated by setup wizard on #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n\n"

        # Add database section with comments
        content += "# Database Configuration\n"
        content += "database:\n"
        content += "  url: #{@generated_config[:database][:url]}\n"
        content += "  pool_size: #{@generated_config[:database][:pool_size]}\n\n"

        # Add AI section with comments
        content += "# AI Provider Configuration\n"
        content += generate_ai_yaml_section

        # Add logger section with comments
        content += "# Logging Configuration\n"
        content += generate_logger_yaml_section

        # Add other sections
        content += generate_remaining_yaml_sections

        content
      end

      # Generate AI configuration YAML section
      #
      # @return [String] AI section YAML
      def generate_ai_yaml_section
        content = "ai:\n"
        content += "  sublayer:\n"
        @generated_config[:ai][:sublayer].each do |key, value|
          content += "    #{key}: #{value}\n"
        end

        content += "  rubyllm:\n"
        @generated_config[:ai][:rubyllm].each do |key, value|
          content += "    #{key}: #{value}\n"
        end

        content += "  openai:\n"
        content += "    log_errors: #{@generated_config[:ai][:openai][:log_errors]}\n"
        content += "  embedding_model: #{@generated_config[:ai][:embedding_model]}\n\n"

        content
      end

      # Generate logger configuration YAML section
      #
      # @return [String] Logger section YAML
      def generate_logger_yaml_section
        content = "logger:\n"
        @generated_config[:logger].each do |key, value|
          content += "  #{key}: #{value}\n"
        end
        content += "\n"

        content
      end

      # Generate remaining configuration YAML sections
      #
      # @return [String] Remaining sections YAML
      def generate_remaining_yaml_sections
        content = ''

        # Editor configuration
        content += "editor:\n"
        @generated_config[:editor].each do |key, value|
          content += "  #{key}: #{value}\n"
        end
        content += "\n"

        # UI configuration
        content += "ui:\n"
        @generated_config[:ui].each do |key, value|
          content += "  #{key}: #{value}\n"
        end
        content += "\n"

        # Features configuration
        content += "features:\n"
        @generated_config[:features].each do |key, value|
          content += "  #{key}: #{value}\n"
        end
        content += "\n"

        # Search configuration
        content += "search:\n"
        @generated_config[:search].each do |key, value|
          content += "  #{key}: #{value}\n"
        end
        content += "\n"

        # Export configuration
        content += "export:\n"
        @generated_config[:export].each do |key, value|
          content += "  #{key}: #{value}\n"
        end
        content += "\n"

        # Performance configuration
        content += "performance:\n"
        @generated_config[:performance].each do |key, value|
          content += "  #{key}: #{value}\n"
        end

        content
      end

      # Get target configuration file path
      #
      # @return [String] Path where config should be saved
      def target_config_path
        # Try to use existing path, fallback to default user config location
        @config.config_file_path || File.join(Dir.home, '.config', 'BlueprintsCLI', 'config.yml')
      end

      # Get default log file path
      #
      # @return [String] Default path for log file
      def default_log_path
        state_home = ENV['XDG_STATE_HOME'] || File.expand_path('~/.local/state')
        File.join(state_home, 'BlueprintsCLI', 'app.log')
      end

      # Provide instructions for environment variables
      def update_environment_instructions
        return unless @setup_data[:providers]

        puts "\n📝 Environment Variables Required:"
        puts 'Add these environment variables to your shell profile:'
        puts ''

        @setup_data[:providers].each_value do |provider_config|
          env_var = provider_config[:env_var]
          puts "export #{env_var}='your_api_key_here'"
        end

        puts ''
        puts '💡 Tip: Create a .env file in your project directory with these variables.'
        puts 'The application will automatically load them on startup.'
      end
    end
  end
end
