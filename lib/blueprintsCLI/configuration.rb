# frozen_string_literal: true

require 'tty-config'
require 'fileutils'
require 'ruby_llm'

OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_ACCESS_TOKEN')
  config.uri_base = ENV.fetch('OPENAI_BASE_URI')
  config.log_errors = true # Highly recommended in development, so you can see what errors OpenAI is returning. Not recommended in production because it could leak private data to your logs.
end

RubyLLM.configure do |config|
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
  config.openai_api_base = ENV.fetch('OPENAI_API_BASE', nil)
  config.default_model = 'gemini-2.0-flash'
  config.default_embedding_model = 'text-embedding-004'
  config.default_image_model = 'imagen-3.0-generate-002'
  config.request_timeout = 120
  config.max_retries = 3
  config.retry_interval = 0.5
  config.retry_backoff_factor = 2
  config.retry_interval_randomness = 0.5
end

module BlueprintsCLI
  # Unified configuration management using TTY::Config
  #
  # Handles configuration for:
  # - BlueprintsCLI application settings
  # - Sublayer AI provider configuration
  # - Ruby LLM provider settings
  # - Logger configuration
  #
  # @example Basic usage
  #   config = BlueprintsCLI::Configuration.new
  #   config.fetch(:blueprints, :database, :url)
  #
  # @example Environment variables
  #   ENV['BLUEPRINTS_DATABASE_URL'] = 'postgres://...'
  #   config.fetch(:blueprints, :database, :url) # Returns env var value
  class Configuration
    # Error raised when configuration validation fails
    ValidationError = Class.new(StandardError)

    # Error raised when required configuration is missing
    MissingConfigError = Class.new(StandardError)

    # Default configuration file name
    DEFAULT_FILENAME = 'config'

    # Default configuration file extension
    DEFAULT_EXTENSION = '.yml'

    # Environment variable prefix for auto-mapping
    ENV_PREFIX = 'BLUEPRINTS'

    # The TTY::Config instance
    attr_reader :config

    # Initialize configuration with optional custom paths
    #
    # @param config_paths [Array<String>] Additional paths to search for config files
    # @param filename [String] Configuration filename (without extension)
    # @param auto_load [Boolean] Whether to automatically load configuration files
    def initialize(config_paths: [], filename: DEFAULT_FILENAME, auto_load: true)
      @config = TTY::Config.new
      setup_config(config_paths, filename)
      load_configuration if auto_load
      setup_validations
    end

    # Fetch a configuration value using nested keys
    #
    # @param keys [Array<Symbol,String>] Nested keys to fetch
    # @param default [Object] Default value if key not found
    # @return [Object] The configuration value
    #
    # @example
    #   config.fetch(:blueprints, :database, :url)
    #   config.fetch(:ai, :sublayer, :provider, default: 'gemini')
    def fetch(*keys, default: nil)
      @config.fetch(*keys, default: default)
    end

    # Set a configuration value using nested keys
    #
    # @param keys [Array<Symbol,String>] Nested keys to set
    # @param value [Object] Value to set
    # @return [Object] The set value
    #
    # @example
    #   config.set(:blueprints, :database, :url, value: 'postgres://...')
    def set(*keys, value:)
      @config.set(*keys, value: value)
      # NOTE: We don't validate on set because it may cause issues during initial setup
      value
    end

    # Check if configuration file exists
    #
    # @return [Boolean] True if config file exists
    def exist?
      @config.exist?
    end

    # Write current configuration to file
    #
    # @param force [Boolean] Whether to overwrite existing file
    # @param create [Boolean] Whether to create missing directories
    # @return [Boolean] True if write succeeded
    def write(force: false, create: true)
      @config.write(force: force, create: create)
      true
    rescue TTY::Config::WriteError => e
      BlueprintsCLI.logger.failure("Failed to write configuration: #{e.message}")
      false
    end

    # Reload configuration from file and environment
    #
    # @return [self]
    def reload!
      @config = TTY::Config.new
      setup_config([], DEFAULT_FILENAME)
      load_configuration
      setup_validations
      self
    end

    # Get configuration file path
    #
    # @return [String, nil] Path to configuration file or nil if not found
    def config_file_path
      @config.source_file
    end

    # Convert configuration to hash
    #
    # @return [Hash] Configuration as hash
    def to_hash
      @config.to_hash
    end
    alias to_h to_hash

    # Validate entire configuration
    #
    # @return [Array<String>] Array of validation error messages (empty if valid)
    def validate!
      errors = []

      begin
        validate_blueprints!
      rescue ValidationError => e
        errors << e.message
      end

      begin
        validate_ai!
      rescue ValidationError => e
        errors << e.message
      end

      begin
        validate_logger!
      rescue ValidationError => e
        errors << e.message
      end

      raise ValidationError, "Configuration validation failed:\n#{errors.join("\n")}" unless errors.empty?

      true
    end

    # Check if configuration is valid
    #
    # @return [Boolean] True if configuration is valid
    def valid?
      validate!
      true
    rescue ValidationError
      false
    end

    # Get database URL with environment variable fallback
    #
    # @return [String, nil] Database URL
    def database_url
      fetch(:blueprints, :database, :url) ||
        ENV['BLUEPRINT_DATABASE_URL'] ||
        ENV['DATABASE_URL']
    end

    # Get AI provider API key for given provider
    #
    # @param provider [String, Symbol] AI provider name
    # @return [String, nil] API key
    def ai_api_key(provider)
      case provider.to_s.downcase
      when 'gemini', 'google'
        ENV['GEMINI_API_KEY'] || ENV['GOOGLE_API_KEY']
      when 'openai'
        ENV['OPENAI_API_KEY']
      when 'anthropic'
        ENV['ANTHROPIC_API_KEY']
      when 'deepseek'
        ENV['DEEPSEEK_API_KEY']
      else
        nil
      end
    end

    # Get Sublayer configuration hash
    #
    # @return [Hash] Sublayer configuration
    def sublayer_config
      {
        project_name: fetch(:ai, :sublayer, :project_name, default: 'blueprintsCLI'),
        project_template: fetch(:ai, :sublayer, :project_template, default: 'CLI'),
        ai_provider: fetch(:ai, :sublayer, :provider, default: 'Gemini'),
        ai_model: fetch(:ai, :sublayer, :model, default: 'gemini-2.0-flash')
      }
    end

    # Get Ruby LLM configuration hash
    #
    # @return [Hash] Ruby LLM configuration
    def ruby_llm_config
      config_hash = {}

      # Add API keys that are available
      config_hash[:openai_api_key] = ai_api_key(:openai) if ai_api_key(:openai)
      config_hash[:anthropic_api_key] = ai_api_key(:anthropic) if ai_api_key(:anthropic)
      config_hash[:google_api_key] = ai_api_key(:gemini) if ai_api_key(:gemini)
      config_hash[:deepseek_api_key] = ai_api_key(:deepseek) if ai_api_key(:deepseek)

      # Add custom API base if configured
      config_hash[:openai_api_base] = fetch(:ai, :ruby_llm, :openai_api_base) if fetch(:ai, :ruby_llm, :openai_api_base)

      config_hash
    end

    private

    # Setup TTY::Config with paths and environment mapping
    def setup_config(config_paths, filename)
      @config.filename = filename
      @config.extname = DEFAULT_EXTENSION
      @config.env_prefix = ENV_PREFIX
      @config.env_separator = '_'
      @config.autoload_env

      # Add default search paths
      default_paths = [
        File.join(Dir.home, '.config', 'BlueprintsCLI'),
        File.join(Dir.home, '.blueprintsCLI'),
        File.join(__dir__, 'config'),
        Dir.pwd
      ]

      (default_paths + config_paths).each do |path|
        @config.append_path(path) if Dir.exist?(path)
      end
    end

    # Load configuration from file and set defaults
    def load_configuration
      # Try to read existing configuration file
      begin
        @config.read if @config.exist?
      rescue TTY::Config::ReadError => e
        BlueprintsCLI.logger.warn("Failed to read configuration file: #{e.message}")
      end

      # Set default values
      set_defaults

      # Map common environment variables
      setup_env_mappings
    end

    # Set default configuration values
    def set_defaults
      # Blueprints defaults
      @config.set_if_empty(:blueprints, :database, :url,
                           value: 'postgresql://postgres:blueprints@ninjabot:5433/blueprints_development')
      @config.set_if_empty(:blueprints, :features, :auto_description, value: true)
      @config.set_if_empty(:blueprints, :features, :auto_categorize, value: true)
      @config.set_if_empty(:blueprints, :features, :improvement_analysis, value: true)
      @config.set_if_empty(:blueprints, :editor, value: ENV['EDITOR'] || ENV['VISUAL'] || 'vim')
      @config.set_if_empty(:blueprints, :auto_save_edits, value: false)
      @config.set_if_empty(:blueprints, :search, :default_limit, value: 10)
      @config.set_if_empty(:blueprints, :search, :semantic_search, value: true)
      @config.set_if_empty(:blueprints, :export, :include_metadata, value: false)
      @config.set_if_empty(:blueprints, :export, :auto_detect_extension, value: true)
      @config.set_if_empty(:blueprints, :performance, :batch_size, value: 100)
      @config.set_if_empty(:blueprints, :performance, :connection_pool_size, value: 5)
      @config.set_if_empty(:blueprints, :ui, :colors, value: true)
      @config.set_if_empty(:blueprints, :ui, :interactive, value: true)
      @config.set_if_empty(:blueprints, :ui, :pager, value: true)

      # AI defaults
      @config.set_if_empty(:ai, :sublayer, :project_name, value: 'blueprintsCLI')
      @config.set_if_empty(:ai, :sublayer, :project_template, value: 'CLI')
      @config.set_if_empty(:ai, :sublayer, :provider, value: 'Gemini')
      @config.set_if_empty(:ai, :sublayer, :model, value: 'gemini-2.0-flash')
      @config.set_if_empty(:ai, :embedding_model, value: 'text-embedding-004')

      # Logger defaults
      @config.set_if_empty(:logger, :level, value: 'info')
      @config.set_if_empty(:logger, :file_logging, value: false)
      @config.set_if_empty(:logger, :file_level, value: 'debug')
      @config.set_if_empty(:logger, :file_path, value: default_log_path)
    end

    # Setup environment variable mappings
    def setup_env_mappings
      # Database
      @config.set_from_env(:blueprints, :database, :url) { 'BLUEPRINT_DATABASE_URL' }
      @config.set_from_env(:blueprints, :database, :url) { 'DATABASE_URL' }

      # Editor
      @config.set_from_env(:blueprints, :editor) { 'EDITOR' }
      @config.set_from_env(:blueprints, :editor) { 'VISUAL' }

      # Debug mode
      @config.set_from_env(:blueprints, :debug) { 'DEBUG' }
      @config.set_from_env(:blueprints, :debug) { 'BLUEPRINTS_DEBUG' }
    end

    # Setup validation rules
    def setup_validations
      # Database URL validation
      @config.validate(:blueprints, :database, :url) do |key, value|
        raise ValidationError, "#{key} must be a non-empty string" unless value.is_a?(String) && !value.empty?

        unless value.start_with?('postgres://') || value.start_with?('postgresql://')
          raise ValidationError, "#{key} must be a PostgreSQL URL (postgres:// or postgresql://)"
        end
      end

      # Feature flags validation
      @config.validate(:blueprints, :features, :auto_description) do |key, value|
        raise ValidationError, "#{key} must be true or false" unless [true, false].include?(value)
      end

      @config.validate(:blueprints, :features, :auto_categorize) do |key, value|
        raise ValidationError, "#{key} must be true or false" unless [true, false].include?(value)
      end

      # Numeric validations
      @config.validate(:blueprints, :search, :default_limit) do |key, value|
        raise ValidationError, "#{key} must be a positive integer" unless value.is_a?(Integer) && value > 0
      end

      @config.validate(:blueprints, :performance, :batch_size) do |key, value|
        raise ValidationError, "#{key} must be a positive integer" unless value.is_a?(Integer) && value > 0
      end

      # AI provider validation
      @config.validate(:ai, :sublayer, :provider) do |key, value|
        valid_providers = %w[Gemini OpenAI Anthropic DeepSeek]
        unless valid_providers.include?(value)
          raise ValidationError, "#{key} must be one of: #{valid_providers.join(', ')}"
        end
      end

      # Logger level validation
      @config.validate(:logger, :level) do |key, value|
        valid_levels = %w[debug info warn error fatal]
        unless valid_levels.include?(value.to_s.downcase)
          raise ValidationError, "#{key} must be one of: #{valid_levels.join(', ')}"
        end
      end
    end

    # Validate blueprints section
    def validate_blueprints!
      database_url = fetch(:blueprints, :database, :url)
      # Only validate if we're not using the default fallback
      return unless database_url.nil? || (database_url.empty? && !ENV['BLUEPRINT_DATABASE_URL'] && !ENV['DATABASE_URL'])

      raise ValidationError, 'Database URL is required'
    end

    # Validate AI section
    def validate_ai!
      provider = fetch(:ai, :sublayer, :provider)
      model = fetch(:ai, :sublayer, :model)

      raise ValidationError, 'AI provider is required' if provider.nil? || provider.empty?

      raise ValidationError, 'AI model is required' if model.nil? || model.empty?

      # Check if API key is available for the provider
      api_key = ai_api_key(provider)
      return unless api_key.nil? || api_key.empty?

      BlueprintsCLI.logger.warn("No API key found for AI provider '#{provider}'. Set the appropriate environment variable.")
    end

    # Validate logger section
    def validate_logger!
      level = fetch(:logger, :level)
      if level && !%w[debug info warn error fatal].include?(level.to_s.downcase)
        raise ValidationError, "Invalid logger level: #{level}"
      end

      return unless fetch(:logger, :file_logging) && fetch(:logger, :file_path).nil?

      raise ValidationError, 'Logger file path is required when file logging is enabled'
    end

    # Get default log file path
    def default_log_path
      state_home = ENV['XDG_STATE_HOME'] || File.expand_path('~/.local/state')
      File.join(state_home, 'BlueprintsCLI', 'app.log')
    end
  end
end
