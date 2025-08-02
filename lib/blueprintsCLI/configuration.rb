# frozen_string_literal: true

require 'tty-config'
require 'fileutils'
require 'ruby_llm'

# Provider configurations are now handled by the unified config system
# See BlueprintsCLI::Configuration#configure_providers method

module BlueprintsCLI
  # Unified configuration management system using TTY::Config for BlueprintsCLI
  #
  # This class provides a comprehensive configuration management system that handles
  # configuration for the entire BlueprintsCLI application. It manages settings for
  # the application itself, AI providers (Sublayer and RubyLLM), database connections,
  # logging, and user interface preferences.
  #
  # The configuration system supports multiple configuration sources including:
  # - YAML configuration files in standard locations
  # - Environment variables with automatic prefix mapping
  # - Interactive setup through TTY::Prompt
  # - Programmatic configuration via the API
  #
  # Configuration files are searched in the following order:
  # 1. ~/.config/BlueprintsCLI/config.yml
  # 2. ~/.blueprintsCLI/config.yml
  # 3. lib/blueprintsCLI/config/config.yml
  # 4. ./config.yml (current directory)
  #
  # Environment variables are automatically mapped using the BLUEPRINTS_ prefix,
  # with nested configuration keys separated by underscores.
  #
  # @example Basic configuration usage
  #   config = BlueprintsCLI::Configuration.new
  #   database_url = config.fetch(:blueprints, :database, :url)
  #   config.set(:logger, :level, value: 'debug')
  #
  # @example Environment variable mapping
  #   ENV['BLUEPRINTS_DATABASE_URL'] = 'postgres://localhost/blueprints'
  #   config.fetch(:blueprints, :database, :url) # Returns the environment variable value
  #
  # @example Interactive setup
  #   config = BlueprintsCLI::Configuration.new(auto_load: false)
  #   config.interactive_setup
  #   config.save_config
  #
  # @example Validation
  #   config = BlueprintsCLI::Configuration.new
  #   if config.valid?
  #     puts "Configuration is valid"
  #   else
  #     config.validate! # Raises ValidationError with details
  #   end
  #
  # @since 0.1.0
  # @see TTY::Config
  # @see BlueprintsCLI::CLI for command-line interface usage
  class Configuration
    # Error raised when configuration validation fails
    #
    # This error is raised when the configuration contains invalid values
    # that don't meet the validation criteria defined in the validation rules.
    #
    # @example Handling validation errors
    #   begin
    #     config.validate!
    #   rescue BlueprintsCLI::Configuration::ValidationError => e
    #     puts "Configuration is invalid: #{e.message}"
    #   end
    #
    # @since 0.1.0
    ValidationError = Class.new(StandardError)

    # Error raised when required configuration is missing
    #
    # This error is raised when attempting to access configuration values
    # that are required but not present in any configuration source.
    #
    # @example Handling missing configuration
    #   begin
    #     config.fetch(:required, :key)
    #   rescue BlueprintsCLI::Configuration::MissingConfigError => e
    #     puts "Missing required configuration: #{e.message}"
    #   end
    #
    # @since 0.1.0
    MissingConfigError = Class.new(StandardError)

    # Default configuration file name (without extension)
    #
    # This constant defines the default filename used when searching for
    # configuration files in the configured search paths.
    #
    # @since 0.1.0
    DEFAULT_FILENAME = 'config'

    # Default configuration file extension
    #
    # This constant defines the file extension used for configuration files.
    # The configuration system will look for files with this extension.
    #
    # @since 0.1.0
    DEFAULT_EXTENSION = '.yml'

    # Environment variable prefix for auto-mapping
    #
    # This prefix is used to automatically map environment variables to
    # configuration keys. Environment variables starting with this prefix
    # will be automatically mapped to configuration values.
    #
    # @example Environment variable mapping
    #   ENV['BLUEPRINTS_DATABASE_URL'] maps to config.fetch(:blueprints, :database, :url)
    #   ENV['BLUEPRINTS_LOGGER_LEVEL'] maps to config.fetch(:logger, :level)
    #
    # @since 0.1.0
    ENV_PREFIX = 'BLUEPRINTS'

    # The underlying TTY::Config instance
    #
    # This accessor provides direct access to the TTY::Config instance for
    # advanced configuration operations that are not covered by the wrapper methods.
    #
    # @return [TTY::Config] The TTY::Config instance managing configuration data
    # @since 0.1.0
    # @see TTY::Config
    attr_reader :config

    # Initialize a new Configuration instance
    #
    # Creates a new configuration management instance with support for multiple
    # configuration sources including YAML files and environment variables.
    # The configuration system automatically searches for configuration files
    # in standard locations and sets up environment variable mapping.
    #
    # @param config_paths [Array<String>] Additional filesystem paths to search for configuration files.
    #   These paths are added to the default search paths and will be checked for configuration files.
    # @param filename [String] The base filename (without extension) to search for in configuration paths.
    #   Defaults to 'config', resulting in searches for 'config.yml' files.
    # @param auto_load [Boolean] Whether to automatically load configuration files and set up defaults.
    #   When true, performs full initialization including file loading, default values, and validation setup.
    #   When false, creates the instance but requires manual loading via {#load_configuration}.
    #
    # @example Basic initialization
    #   config = BlueprintsCLI::Configuration.new
    #   # Searches default paths for 'config.yml' and loads automatically
    #
    # @example Custom paths and filename
    #   config = BlueprintsCLI::Configuration.new(
    #     config_paths: ['/etc/blueprints', '/usr/local/etc'],
    #     filename: 'blueprints_config'
    #   )
    #
    # @example Deferred loading
    #   config = BlueprintsCLI::Configuration.new(auto_load: false)
    #   # Perform custom setup...
    #   config.load_configuration
    #
    # @raise [TTY::Config::ReadError] if configuration file exists but cannot be read
    # @raise [ValidationError] if auto_load is true and configuration validation fails
    #
    # @since 0.1.0
    # @see #load_configuration
    # @see #setup_config
    def initialize(config_paths: [], filename: DEFAULT_FILENAME, auto_load: true)
      @config = TTY::Config.new
      setup_config(config_paths, filename)
      load_configuration if auto_load
      setup_validations
    end

    # Fetch a configuration value using nested keys
    #
    # Retrieves configuration values using a sequence of nested keys, with support
    # for default values when the configuration path doesn't exist. This method
    # searches through all configuration sources including YAML files and environment
    # variables mapped through the configured prefix.
    #
    # @param keys [Array<Symbol,String>] Sequence of nested keys to navigate the configuration hierarchy.
    #   Keys can be symbols or strings and represent the path to the desired configuration value.
    # @param default [Object] Default value to return if the configuration path doesn't exist.
    #   Can be any Ruby object. If not provided, returns nil for missing keys.
    #
    # @return [Object] The configuration value found at the specified path, or the default value
    #   if the path doesn't exist.
    #
    # @example Basic value retrieval
    #   config.fetch(:blueprints, :database, :url)
    #   # => "postgresql://localhost:5432/blueprints"
    #
    # @example With default value
    #   config.fetch(:ai, :sublayer, :provider, default: 'gemini')
    #   # => "gemini" (if not configured)
    #
    # @example Environment variable mapping
    #   ENV['BLUEPRINTS_LOGGER_LEVEL'] = 'debug'
    #   config.fetch(:logger, :level)
    #   # => "debug"
    #
    # @example Nested configuration access
    #   config.fetch(:blueprints, :features, :auto_description)
    #   # => true
    #
    # @since 0.1.0
    # @see #set
    # @see TTY::Config#fetch
    def fetch(*keys, default: nil)
      @config.fetch(*keys, default: default)
    end

    # Set a configuration value using nested keys
    #
    # Sets configuration values at the specified nested key path. This method
    # allows programmatic configuration of values, which is useful for dynamic
    # configuration updates or during interactive setup processes.
    #
    # Note that validation is not performed during set operations to avoid
    # issues during initial configuration setup. Validation should be performed
    # explicitly using {#validate!} after configuration is complete.
    #
    # @param keys [Array<Symbol,String>] Sequence of nested keys defining where to set the value.
    #   Creates the nested structure if it doesn't exist.
    # @param value [Object] The value to set at the specified configuration path.
    #   Can be any Ruby object that can be serialized to YAML.
    #
    # @return [Object] The value that was set, allowing for method chaining.
    #
    # @example Setting database configuration
    #   config.set(:blueprints, :database, :url, value: 'postgres://localhost/blueprints')
    #   # => "postgres://localhost/blueprints"
    #
    # @example Setting logger level
    #   config.set(:logger, :level, value: 'debug')
    #   # => "debug"
    #
    # @example Setting complex nested values
    #   config.set(:ai, :rubyllm, :max_retries, value: 5)
    #   # => 5
    #
    # @note Validation is not performed during set operations. Use {#validate!} to check configuration validity.
    #
    # @since 0.1.0
    # @see #fetch
    # @see #validate!
    def set(*keys, value:)
      @config.set(*keys, value: value)
      # NOTE: We don't validate on set because it may cause issues during initial setup
      value
    end

    # Check if configuration file exists
    #
    # Determines whether a configuration file exists in any of the configured
    # search paths. This is useful for determining whether to prompt for
    # initial setup or load existing configuration.
    #
    # @return [Boolean] true if a configuration file exists in any search path,
    #   false if no configuration file is found.
    #
    # @example Check for existing configuration
    #   if config.exist?
    #     puts "Loading existing configuration"
    #   else
    #     puts "No configuration found, running setup"
    #     config.interactive_setup
    #   end
    #
    # @since 0.1.0
    # @see TTY::Config#exist?
    def exist?
      @config.exist?
    end

    # Write current configuration to file
    #
    # Persists the current configuration state to a YAML file in the first
    # writable location from the configured search paths. Creates necessary
    # directories if they don't exist and the create option is enabled.
    #
    # @param force [Boolean] Whether to overwrite an existing configuration file.
    #   When false, will not overwrite existing files and may raise an error.
    # @param create [Boolean] Whether to create missing parent directories.
    #   When true, creates the directory structure needed for the configuration file.
    #
    # @return [Boolean] true if the configuration was successfully written to file,
    #   false if the write operation failed.
    #
    # @example Write configuration with defaults
    #   config.write
    #   # => true (if successful)
    #
    # @example Force overwrite existing file
    #   config.write(force: true)
    #   # => true
    #
    # @example Write without creating directories
    #   config.write(create: false)
    #   # => false (if directory doesn't exist)
    #
    # @raise [TTY::Config::WriteError] when write operation fails and error handling is disabled
    #
    # @since 0.1.0
    # @see TTY::Config#write
    def write(force: false, create: true)
      @config.write(force: force, create: create)
      true
    rescue TTY::Config::WriteError => e
      BlueprintsCLI.logger.failure("Failed to write configuration: #{e.message}")
      false
    end

    # Reload configuration from file and environment
    #
    # Completely reinitializes the configuration system by creating a new
    # TTY::Config instance and reloading all configuration sources including
    # files and environment variables. This is useful when configuration
    # files have been modified externally or environment variables have changed.
    #
    # @return [self] Returns self to allow method chaining.
    #
    # @example Reload after external configuration changes
    #   config.reload!
    #   updated_value = config.fetch(:blueprints, :database, :url)
    #
    # @example Method chaining
    #   config.reload!.validate!
    #
    # @since 0.1.0
    # @see #initialize
    # @see #load_configuration
    def reload!
      @config = TTY::Config.new
      setup_config([], DEFAULT_FILENAME)
      load_configuration
      setup_validations
      self
    end

    # Get the path to the currently loaded configuration file
    #
    # Returns the filesystem path to the configuration file that was loaded,
    # or nil if no configuration file was found during initialization.
    # This is useful for displaying the source of configuration to users
    # or for backup/editing operations.
    #
    # @return [String, nil] The absolute path to the configuration file if one
    #   was loaded, or nil if configuration is only from defaults and environment variables.
    #
    # @example Display configuration source
    #   path = config.config_file_path
    #   if path
    #     puts "Configuration loaded from: #{path}"
    #   else
    #     puts "Using default configuration"
    #   end
    #
    # @since 0.1.0
    # @see TTY::Config#source_file
    def config_file_path
      @config.source_file
    end

    # Convert the entire configuration to a hash
    #
    # Returns a complete hash representation of the current configuration,
    # including all nested structures. This is useful for debugging,
    # serialization, or when you need to work with the configuration
    # data as a standard Ruby hash.
    #
    # @return [Hash] A hash containing all configuration data with symbol keys
    #   representing the nested configuration structure.
    #
    # @example Export configuration
    #   config_hash = config.to_hash
    #   puts config_hash[:blueprints][:database][:url]
    #
    # @example Serialize configuration
    #   File.write('config_backup.yml', config.to_hash.to_yaml)
    #
    # @since 0.1.0
    # @see #to_h
    # @see TTY::Config#to_hash
    def to_hash
      @config.to_hash
    end
    alias to_h to_hash

    # Validate the entire configuration
    #
    # Performs comprehensive validation of all configuration sections including
    # blueprints, AI providers, and logger settings. Validates data types,
    # required fields, value ranges, and cross-section dependencies.
    #
    # This method collects all validation errors and raises a single
    # ValidationError containing all issues found, making it easy to
    # present complete validation feedback to users.
    #
    # @return [true] Returns true if all validation passes.
    #
    # @raise [ValidationError] if any validation rules fail. The error message
    #   contains details about all validation failures found.
    #
    # @example Validate configuration
    #   begin
    #     config.validate!
    #     puts "Configuration is valid"
    #   rescue BlueprintsCLI::Configuration::ValidationError => e
    #     puts "Validation failed:\n#{e.message}"
    #   end
    #
    # @since 0.1.0
    # @see #valid?
    # @see #validate_blueprints!
    # @see #validate_ai!
    # @see #validate_logger!
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

      unless errors.empty?
        raise ValidationError,
              "Configuration validation failed:\n#{errors.join("\n")}"
      end

      true
    end

    # Check if configuration is valid without raising exceptions
    #
    # Performs the same validation as {#validate!} but returns a boolean
    # result instead of raising exceptions. This is useful for conditional
    # logic where you want to check validity without handling exceptions.
    #
    # @return [Boolean] true if all configuration validation passes,
    #   false if any validation rules fail.
    #
    # @example Conditional validation check
    #   if config.valid?
    #     proceed_with_operation
    #   else
    #     show_configuration_errors
    #   end
    #
    # @since 0.1.0
    # @see #validate!
    def valid?
      validate!
      true
    rescue ValidationError
      false
    end

    # Get database URL with intelligent fallback strategy
    #
    # Attempts to retrieve the database URL from multiple sources in order
    # of preference: configuration file, BLUEPRINT_DATABASE_URL environment
    # variable, DATABASE_URL environment variable, and finally constructs
    # a URL from individual database environment variables.
    #
    # @return [String, nil] The database URL to use for connections, or nil
    #   if no database configuration can be determined.
    #
    # @example Get database URL
    #   url = config.database_url
    #   # => "postgresql://user:pass@localhost:5432/blueprints"
    #
    # @example Environment variable precedence
    #   ENV['BLUEPRINT_DATABASE_URL'] = 'postgres://custom/db'
    #   config.database_url
    #   # => "postgres://custom/db"
    #
    # @since 0.1.0
    # @see #build_database_url
    def database_url
      fetch(:blueprints, :database, :url) ||
        ENV['BLUEPRINT_DATABASE_URL'] ||
        ENV['DATABASE_URL'] ||
        build_database_url
    end

    # Build database URL from individual environment variables
    #
    # Constructs a PostgreSQL connection URL using individual database
    # configuration environment variables. This provides a fallback when
    # no complete database URL is available from other sources.
    #
    # Uses the following environment variables with sensible defaults:
    # - DB_HOST (default: 'localhost')
    # - DB_PORT (default: '5432')
    # - DB_USER (default: 'postgres')
    # - DB_PASSWORD (default: 'blueprints')
    # - DB_NAME (default: 'blueprints')
    #
    # @return [String] A complete PostgreSQL connection URL constructed from
    #   environment variables and defaults.
    #
    # @example Default construction
    #   config.build_database_url
    #   # => "postgresql://postgres:blueprints@localhost:5432/blueprints"
    #
    # @example With environment variables
    #   ENV['DB_HOST'] = 'db.example.com'
    #   ENV['DB_USER'] = 'myapp'
    #   ENV['DB_PASSWORD'] = 'secret'
    #   config.build_database_url
    #   # => "postgresql://myapp:secret@db.example.com:5432/blueprints"
    #
    # @since 0.1.0
    # @see #database_url
    def build_database_url
      host = ENV['DB_HOST'] || 'localhost'
      port = ENV['DB_PORT'] || '5432'
      user = ENV['DB_USER'] || 'postgres'
      password = ENV['DB_PASSWORD'] || 'blueprints'
      database = ENV['DB_NAME'] || 'blueprints'

      "postgresql://#{user}:#{password}@#{host}:#{port}/#{database}"
    end

    # Get API key for the specified AI provider
    #
    # Retrieves API keys for supported AI providers from environment variables.
    # Supports multiple environment variable names for each provider to
    # accommodate different naming conventions and legacy compatibility.
    #
    # Supported providers and their environment variables:
    # - gemini/google: GEMINI_API_KEY, GOOGLE_API_KEY
    # - openai: OPENROUTER_API_KEY, OPENAI_API_KEY
    # - anthropic: ANTHROPIC_API_KEY
    # - deepseek: DEEPSEEK_API_KEY
    #
    # @param provider [String, Symbol] The AI provider name. Case-insensitive.
    #   Supported values: 'gemini', 'google', 'openai', 'anthropic', 'deepseek'.
    #
    # @return [String, nil] The API key for the specified provider, or nil
    #   if no API key is found in environment variables.
    #
    # @example Get Gemini API key
    #   config.ai_api_key(:gemini)
    #   # => "your-gemini-api-key" (from GEMINI_API_KEY or GOOGLE_API_KEY)
    #
    # @example Get OpenAI API key with fallback
    #   config.ai_api_key('openai')
    #   # => "your-openai-key" (from OPENROUTER_API_KEY or OPENAI_API_KEY)
    #
    # @example Case insensitive
    #   config.ai_api_key('ANTHROPIC')
    #   # => "your-anthropic-key"
    #
    # @since 0.1.0
    # @see #ruby_llm_config
    # @see #sublayer_config
    def ai_api_key(provider)
      case provider.to_s.downcase
      when 'gemini', 'google'
        ENV['GEMINI_API_KEY'] || ENV['GOOGLE_API_KEY']
      when 'openai'
        # Support both OpenRouter and direct OpenAI
        ENV['OPENROUTER_API_KEY'] || ENV['OPENAI_API_KEY']
      when 'anthropic'
        ENV['ANTHROPIC_API_KEY']
      when 'deepseek'
        ENV['DEEPSEEK_API_KEY']
      end
    end

    # Get Sublayer AI framework configuration
    #
    # Returns a hash containing all configuration values needed to initialize
    # the Sublayer AI framework. Sublayer is used for AI-powered code analysis
    # and generation within BlueprintsCLI.
    #
    # @return [Hash] A hash containing Sublayer configuration with the following keys:
    #   - :project_name [String] The project name for Sublayer (default: 'blueprintsCLI')
    #   - :project_template [String] The project template type (default: 'CLI')
    #   - :ai_provider [String] The AI provider to use (default: 'Gemini')
    #   - :ai_model [String] The specific AI model (default: 'gemini-2.0-flash')
    #
    # @example Get Sublayer configuration
    #   sublayer_config = config.sublayer_config
    #   # => {
    #   #      project_name: 'blueprintsCLI',
    #   #      project_template: 'CLI',
    #   #      ai_provider: 'Gemini',
    #   #      ai_model: 'gemini-2.0-flash'
    #   #    }
    #
    # @example Use with Sublayer initialization
    #   Sublayer.configure(config.sublayer_config)
    #
    # @since 0.1.0
    # @see Sublayer
    # @see #ai_api_key
    def sublayer_config
      {
        project_name: fetch(:ai, :sublayer, :project_name, default: 'blueprintsCLI'),
        project_template: fetch(:ai, :sublayer, :project_template, default: 'CLI'),
        ai_provider: fetch(:ai, :sublayer, :provider, default: 'Gemini'),
        ai_model: fetch(:ai, :sublayer, :model, default: 'gemini-2.0-flash')
      }
    end

    # Get RubyLLM library configuration
    #
    # Returns a hash containing all API keys and configuration values needed
    # to initialize the RubyLLM library. Only includes API keys that are
    # actually available in environment variables to avoid configuration errors.
    #
    # The RubyLLM library provides a unified interface to multiple AI providers
    # including OpenAI, Anthropic, Gemini, and DeepSeek.
    #
    # @return [Hash] A hash containing available RubyLLM configuration. May include:
    #   - :openai_api_key [String] OpenAI API key (if available)
    #   - :anthropic_api_key [String] Anthropic API key (if available)
    #   - :gemini_api_key [String] Gemini API key (if available)
    #   - :deepseek_api_key [String] DeepSeek API key (if available)
    #   - :openai_api_base [String] Custom OpenAI endpoint (if configured)
    #
    # @example Get RubyLLM configuration
    #   ruby_llm_config = config.ruby_llm_config
    #   # => { gemini_api_key: 'your-key', openai_api_key: 'another-key' }
    #
    # @example Use with RubyLLM initialization
    #   RubyLLM.configure(config.ruby_llm_config)
    #
    # @since 0.1.0
    # @see RubyLLM
    # @see #ai_api_key
    def ruby_llm_config
      config_hash = {}

      # Add API keys that are available
      config_hash[:openai_api_key] = ai_api_key(:openai) if ai_api_key(:openai)
      config_hash[:anthropic_api_key] = ai_api_key(:anthropic) if ai_api_key(:anthropic)
      config_hash[:gemini_api_key] = ai_api_key(:gemini) if ai_api_key(:gemini)
      config_hash[:deepseek_api_key] = ai_api_key(:deepseek) if ai_api_key(:deepseek)

      # Add custom API base if configured
      config_hash[:openai_api_base] = fetch(:ai, :ruby_llm, :openai_api_base) if fetch(:ai,
                                                                                       :ruby_llm, :openai_api_base)

      config_hash
    end

    # Run interactive configuration setup wizard
    #
    # Provides a guided, interactive configuration setup process using TTY::Prompt.
    # This method walks users through configuring all major aspects of BlueprintsCLI
    # including database connection, AI providers, logging, and editor preferences.
    #
    # The setup process includes:
    # 1. Database configuration (URL or connection parameters)
    # 2. AI provider selection and API key configuration
    # 3. Logger settings (level, file logging options)
    # 4. Editor preferences and auto-save settings
    # 5. Automatic configuration file creation and validation
    #
    # @return [Boolean] true if setup completed successfully, false if errors occurred.
    #
    # @example Run interactive setup
    #   config = BlueprintsCLI::Configuration.new(auto_load: false)
    #   if config.interactive_setup\n    #     puts \"Configuration setup completed successfully\"\n    #   else\n    #     puts \"Setup failed, check error messages\"\n    #   end\n    #\n    # @example First-time user experience\n    #   unless config.exist?\n    #     puts \"Welcome to BlueprintsCLI! Let's set up your configuration.\"\n    #     config.interactive_setup\n    #   end\n    #\n    # @raise [StandardError] Various errors may be raised during setup,\n    #   which are caught and logged as failure messages.\n    #\n    # @since 0.1.0\n    # @see TTY::Prompt\n    # @see #save_config\n    # @see #validate!\n    def interactive_setup
    require 'tty-prompt'
    prompt = TTY::Prompt.new

    puts '🔧 BlueprintsCLI Interactive Configuration Setup'
    puts '=' * 50

    # Database configuration
    configure_database_interactive(prompt)

    # AI provider configuration
    configure_ai_interactive(prompt)

    # Logger configuration
    configure_logger_interactive(prompt)

    # Editor configuration
    configure_editor_interactive(prompt)

    # Save configuration
    save_config

    true
  rescue StandardError => e
    BlueprintsCLI.logger.failure("Error during interactive setup: #{e.message}")
    false
  end

  # Configure logger settings interactively
  #
  # Provides an interactive interface for configuring logger settings including
  # console log level, file logging options, and log file paths. This method
  # is used both during initial setup and when editing specific configuration sections.
  #
  # @return [void]
  #
  # @example Configure logger independently
  #   config.configure_logger
  #   # Prompts for logger level, file logging, etc.
  #
  # @since 0.1.0
  # @see #configure_logger_interactive
  def configure_logger
    configure_logger_interactive(TTY::Prompt.new)
  end

  # Configure filesystem path settings interactively
  #
  # Provides an interactive interface for configuring filesystem paths
  # used by BlueprintsCLI, such as temporary directories for editor operations.
  #
  # @return [void]
  #
  # @example Configure paths
  #   config.configure_paths
  #   # Prompts for temporary directory path
  #
  # @since 0.1.0
  def configure_paths
    prompt = TTY::Prompt.new
    puts "\n📁 Path Configuration"

    temp_dir = prompt.ask('Temporary directory:', default: fetch(:editor, :temp_dir) || '/tmp')
    set(:editor, :temp_dir, value: temp_dir)
  end

  # Configure display and UI settings interactively
  #
  # Provides an interactive interface for configuring user interface settings
  # including colored output, interactive prompts, and pager configuration.
  #
  # @return [void]
  #
  # @example Configure display settings
  #   config.configure_display
  #   # Prompts for colors, interactive mode, pager choice
  #
  # @since 0.1.0
  def configure_display
    prompt = TTY::Prompt.new
    puts "\n🎨 Display Configuration"

    colors = prompt.yes?('Enable colored output?', default: fetch(:ui, :colors, default: true))
    set(:ui, :colors, value: colors)

    interactive_mode = prompt.yes?('Enable interactive prompts?',
                                   default: fetch(:ui, :interactive, default: true))
    set(:ui, :interactive, value: interactive_mode)

    pager = prompt.ask('Pager command:', default: fetch(:ui, :pager) || 'most')
    set(:ui, :pager, value: pager)
  end

  # Configure Restic backup settings interactively (placeholder)
  #
  # This method is a placeholder for future Restic backup configuration.
  # Currently displays a message indicating the feature is not implemented.
  #
  # @return [void]
  #
  # @note This method is not yet implemented and serves as a placeholder
  #   for future backup configuration functionality.
  #
  # @since 0.1.0
  def configure_restic
    # Placeholder for restic configuration if needed
    puts "\n💾 Restic Configuration (not implemented yet)"
  end

  # Configure terminal settings interactively (placeholder)
  #
  # This method is a placeholder for future terminal configuration options.
  # Currently displays a message indicating the feature is not implemented.
  #
  # @return [void]
  #
  # @note This method is not yet implemented and serves as a placeholder
  #   for future terminal configuration functionality.
  #
  # @since 0.1.0
  def configure_terminals
    # Placeholder for terminal configuration if needed
    puts "\n🖥️  Terminal Configuration (not implemented yet)"
  end

  # Save current configuration to file with force overwrite
  #
  # Convenience method that saves the current configuration state to file
  # with force overwrite enabled. This is typically used after interactive
  # setup or configuration changes to persist the updates.
  #
  # @return [Boolean] true if save was successful, false otherwise.
  #
  # @example Save configuration after changes
  #   config.set(:logger, :level, value: 'debug')
  #   config.save_config
  #   # => true
  #
  # @since 0.1.0
  # @see #write
  def save_config
    write(force: true)
  end

  private

  # Validate terminal command availability (placeholder)
  #
  # This method is a placeholder for validating that configured terminal
  # commands are available on the system. Currently returns true as a
  # basic implementation.
  #
  # @return [Boolean] Always returns true in current implementation.
  #
  # @note This is a placeholder implementation that could be extended
  #   to check if configured terminal commands are available in PATH.
  #
  # @since 0.1.0
  # @api private
  def validate_terminal_command
    # This is a placeholder validation - just return true for now
    # Could be extended to check if configured terminal commands are available
    true
  end

  # Configure database settings interactively
  #
  # Prompts the user for database configuration including the database URL.
  # Uses existing configuration values as defaults when available.
  #
  # @param prompt [TTY::Prompt] The prompt instance for user interaction.
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def configure_database_interactive(prompt)
    puts "\n📊 Database Configuration"

    current_url = fetch(:database, :url) || fetch(:blueprints, :database, :url)
    database_url = prompt.ask('Database URL:', default: current_url)

    set(:database, :url, value: database_url) if database_url
  end

  # Configure AI provider settings interactively
  #
  # Prompts the user to select an AI provider and optionally configure
  # API keys. Supports Gemini, OpenAI, Anthropic, and DeepSeek providers.
  # API keys can be left empty to use environment variables.
  #
  # @param prompt [TTY::Prompt] The prompt instance for user interaction.
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def configure_ai_interactive(prompt)
    puts "\n🤖 AI Provider Configuration"

    provider = prompt.select('Select AI provider:', %w[Gemini OpenAI Anthropic DeepSeek])
    set(:ai, :sublayer, :provider, value: provider)

    case provider.downcase
    when 'gemini'
      api_key = prompt.mask('Gemini API Key (leave empty to use environment variable):')
      set(:ai, :provider_keys, :gemini, value: api_key) unless api_key.empty?
    when 'openai'
      api_key = prompt.mask('OpenAI API Key (leave empty to use environment variable):')
      set(:ai, :provider_keys, :openai, value: api_key) unless api_key.empty?
    when 'anthropic'
      api_key = prompt.mask('Anthropic API Key (leave empty to use environment variable):')
      set(:ai, :provider_keys, :anthropic, value: api_key) unless api_key.empty?
    when 'deepseek'
      api_key = prompt.mask('DeepSeek API Key (leave empty to use environment variable):')
      set(:ai, :provider_keys, :deepseek, value: api_key) unless api_key.empty?
    end
  end

  # Configure logger settings interactively
  #
  # Prompts the user for logger configuration including console log level,
  # file logging options, file log level, and log file path.
  #
  # @param prompt [TTY::Prompt] The prompt instance for user interaction.
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def configure_logger_interactive(prompt)
    puts "\n📝 Logger Configuration"

    level = prompt.select('Console log level:', %w[debug info warn error fatal])
    set(:logger, :level, value: level)

    file_logging = prompt.yes?('Enable file logging?')
    set(:logger, :file_logging, value: file_logging)

    return unless file_logging

    file_level = prompt.select('File log level:', %w[debug info warn error fatal])
    set(:logger, :file_level, value: file_level)

    file_path = prompt.ask('Log file path:', default: default_log_path)
    set(:logger, :file_path, value: file_path)
  end

  # Configure editor settings interactively
  #
  # Prompts the user for editor configuration including default editor
  # selection and auto-save preferences. Uses EDITOR or VISUAL environment
  # variables as defaults when available.
  #
  # @param prompt [TTY::Prompt] The prompt instance for user interaction.
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def configure_editor_interactive(prompt)
    puts "\n✏️  Editor Configuration"

    current_editor = fetch(:editor, :default) || ENV['EDITOR'] || ENV['VISUAL'] || 'vim'
    editor = prompt.ask('Default editor:', default: current_editor)
    set(:editor, :default, value: editor)

    auto_save = prompt.yes?('Enable auto-save for edits?')
    set(:editor, :auto_save, value: auto_save)
  end

  # Setup TTY::Config with paths and environment mapping
  #
  # Initializes the TTY::Config instance with configuration file paths,
  # environment variable mapping, and search paths. This method sets up
  # the foundational configuration system before loading any actual values.
  #
  # @param config_paths [Array<String>] Additional paths to search for configuration files.
  # @param filename [String] Base filename for configuration files (without extension).
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
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
  #
  # Performs the complete configuration loading process including reading
  # configuration files, setting default values, mapping environment variables,
  # and configuring external provider libraries.
  #
  # This method handles errors gracefully and will continue with defaults
  # if configuration files cannot be read.
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def load_configuration
    # Try to read existing configuration file
    begin
      @config.read if @config.exist?
    rescue TTY::Config::ReadError => e
      # Can't use BlueprintsCLI.logger here as it may not be initialized yet
      warn "Failed to read configuration file: #{e.message}"
    end

    # Set default values
    set_defaults

    # Map common environment variables
    setup_env_mappings

    # Configure external providers
    configure_providers
  end

  # Set default configuration values
  #
  # Establishes default values for all configuration sections using
  # TTY::Config's set_if_empty method. This ensures that the application
  # has sensible defaults even when no configuration file is present.
  #
  # Default values include:
  # - Database connection settings
  # - AI provider configurations
  # - Logger settings
  # - UI preferences
  # - Performance tuning parameters
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def set_defaults
    # Blueprints defaults
    @config.set_if_empty(:blueprints, :database, :url,
                         value: 'postgresql://postgres:blueprints@localhost:5432/blueprints')
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

    # RubyLLM defaults
    @config.set_if_empty(:ai, :rubyllm, :default_model, value: 'gemini-2.0-flash')
    @config.set_if_empty(:ai, :rubyllm, :default_embedding_model, value: 'text-embedding-004')
    @config.set_if_empty(:ai, :rubyllm, :default_image_model, value: 'imagen-3.0-generate-002')
    @config.set_if_empty(:ai, :rubyllm, :request_timeout, value: 120)
    @config.set_if_empty(:ai, :rubyllm, :max_retries, value: 3)
    @config.set_if_empty(:ai, :rubyllm, :retry_interval, value: 0.5)
    @config.set_if_empty(:ai, :rubyllm, :retry_backoff_factor, value: 2)
    @config.set_if_empty(:ai, :rubyllm, :retry_interval_randomness, value: 0.5)
    @config.set_if_empty(:ai, :rubyllm, :log_level, value: 'info')
    @config.set_if_empty(:ai, :rubyllm, :log_assume_model_exists, value: false)

    # OpenAI gem defaults
    @config.set_if_empty(:ai, :openai, :log_errors, value: true)

    # Logger defaults
    @config.set_if_empty(:logger, :level, value: 'info')
    @config.set_if_empty(:logger, :file_logging, value: false)
    @config.set_if_empty(:logger, :file_level, value: 'debug')
    @config.set_if_empty(:logger, :file_path, value: default_log_path)
  end

  # Setup environment variable mappings
  #
  # Configures automatic mapping between environment variables and
  # configuration keys. This allows environment variables to override
  # configuration file values and provides flexible deployment options.
  #
  # Mappings include:
  # - Database URLs (BLUEPRINT_DATABASE_URL, DATABASE_URL)
  # - Editor preferences (EDITOR, VISUAL)
  # - Debug settings (DEBUG, BLUEPRINTS_DEBUG)
  # - AI provider API keys (OPENAI_API_KEY, GEMINI_API_KEY, etc.)
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
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

    # AI Provider API keys
    @config.set_from_env(:ai, :provider_keys, :openai) { 'OPENAI_API_KEY' }
    @config.set_from_env(:ai, :provider_keys, :gemini) { 'GEMINI_API_KEY' }
    @config.set_from_env(:ai, :provider_keys, :gemini) { 'GOOGLE_API_KEY' }
    @config.set_from_env(:ai, :provider_keys, :anthropic) { 'ANTHROPIC_API_KEY' }
    @config.set_from_env(:ai, :provider_keys, :deepseek) { 'DEEPSEEK_API_KEY' }
    @config.set_from_env(:ai, :provider_keys, :openai_access_token) { 'OPENAI_ACCESS_TOKEN' }
    @config.set_from_env(:ai, :provider_keys, :openai_base_uri) { 'OPENAI_BASE_URI' }
    @config.set_from_env(:ai, :rubyllm, :openai_api_key) { 'OPENAI_API_KEY' }
    @config.set_from_env(:ai, :rubyllm, :openai_api_base) { 'OPENAI_API_BASE' }
  end

  # Setup validation rules
  #
  # Establishes comprehensive validation rules for all configuration sections.
  # These rules are used by the validate! method to ensure configuration
  # integrity and provide meaningful error messages for invalid values.
  #
  # Validation rules include:
  # - Database URL format validation
  # - Boolean value validation for feature flags
  # - Numeric range validation for performance settings
  # - Enum validation for AI providers and log levels
  # - Required field validation
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def setup_validations
    # Database URL validation
    @config.validate(:blueprints, :database, :url) do |key, value|
      unless value.is_a?(String) && !value.empty?
        raise ValidationError,
              "#{key} must be a non-empty string"
      end

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
      unless value.is_a?(Integer) && value.positive?
        raise ValidationError,
              "#{key} must be a positive integer"
      end
    end

    @config.validate(:blueprints, :performance, :batch_size) do |key, value|
      unless value.is_a?(Integer) && value.positive?
        raise ValidationError,
              "#{key} must be a positive integer"
      end
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

    # RubyLLM timeout validation
    @config.validate(:ai, :rubyllm, :request_timeout) do |key, value|
      unless value.is_a?(Integer) && value.positive?
        raise ValidationError,
              "#{key} must be a positive integer"
      end
    end

    # RubyLLM retry validation
    @config.validate(:ai, :rubyllm, :max_retries) do |key, value|
      unless value.is_a?(Integer) && value >= 0
        raise ValidationError,
              "#{key} must be a non-negative integer"
      end
    end

    # RubyLLM retry interval validation
    @config.validate(:ai, :rubyllm, :retry_interval) do |key, value|
      unless value.is_a?(Numeric) && value >= 0
        raise ValidationError,
              "#{key} must be a non-negative number"
      end
    end

    # RubyLLM log level validation
    @config.validate(:ai, :rubyllm, :log_level) do |key, value|
      valid_levels = %w[debug info warn]
      unless valid_levels.include?(value.to_s.downcase)
        raise ValidationError, "#{key} must be one of: #{valid_levels.join(', ')}"
      end
    end

    # RubyLLM boolean validation
    @config.validate(:ai, :rubyllm, :log_assume_model_exists) do |key, value|
      raise ValidationError, "#{key} must be true or false" unless [true, false].include?(value)
    end
  end

  # Validate blueprints configuration section
  #
  # Validates the blueprints section of the configuration, particularly
  # focusing on database URL availability. Only validates when not using
  # default fallback URLs to avoid false positives.
  #
  # @return [void]
  #
  # @raise [ValidationError] if database URL is required but missing.
  #
  # @since 0.1.0
  # @api private
  def validate_blueprints!
    database_url = fetch(:blueprints, :database, :url)
    # Only validate if we're not using the default fallback
    return unless database_url.nil? || (database_url.empty? && !ENV['BLUEPRINT_DATABASE_URL'] && !ENV['DATABASE_URL'])

    raise ValidationError, 'Database URL is required'
  end

  # Validate AI configuration section
  #
  # Validates AI provider configuration including provider name, model
  # specification, and API key availability. Issues warnings for missing
  # API keys rather than raising errors to allow for environment-specific
  # configuration.
  #
  # @return [void]
  #
  # @raise [ValidationError] if required AI configuration is missing.
  #
  # @since 0.1.0
  # @api private
  def validate_ai!
    provider = fetch(:ai, :sublayer, :provider)
    model = fetch(:ai, :sublayer, :model)

    raise ValidationError, 'AI provider is required' if provider.nil? || provider.empty?

    raise ValidationError, 'AI model is required' if model.nil? || model.empty?

    # Check if API key is available for the provider
    api_key = ai_api_key(provider)
    return unless api_key.nil? || api_key.empty?

    # Can't use BlueprintsCLI.logger here as it may not be initialized yet
    warn "No API key found for AI provider '#{provider}'. Set the appropriate environment variable."
  end

  # Validate logger configuration section
  #
  # Validates logger settings including log level values and file logging
  # configuration. Ensures that file paths are specified when file logging
  # is enabled.
  #
  # @return [void]
  #
  # @raise [ValidationError] if logger configuration is invalid.
  #
  # @since 0.1.0
  # @api private
  def validate_logger!
    level = fetch(:logger, :level)
    if level && !%w[debug info warn error fatal].include?(level.to_s.downcase)
      raise ValidationError, "Invalid logger level: #{level}"
    end

    return unless fetch(:logger, :file_logging) && fetch(:logger, :file_path).nil?

    raise ValidationError, 'Logger file path is required when file logging is enabled'
  end

  # Get default log file path
  #
  # Constructs a default log file path using XDG Base Directory specification.
  # Falls back to ~/.local/state if XDG_STATE_HOME is not set.
  #
  # @return [String] The default log file path.
  #
  # @example Default log path
  #   config.send(:default_log_path)
  #   # => "/home/user/.local/state/BlueprintsCLI/app.log"
  #
  # @since 0.1.0
  # @api private
  def default_log_path
    state_home = ENV['XDG_STATE_HOME'] || File.expand_path('~/.local/state')
    File.join(state_home, 'BlueprintsCLI', 'app.log')
  end

  # Configure external provider libraries based on unified configuration
  #
  # Configures external AI provider libraries (RubyLLM and OpenAI gem)
  # using values from the unified configuration system. This ensures
  # that all provider libraries are properly initialized with the
  # correct API keys and settings.
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def configure_providers
    configure_rubyllm
    configure_openai_gem
  end

  # Configure RubyLLM with settings from unified config system
  #
  # Initializes the RubyLLM library with API keys, model defaults,
  # connection settings, and logging configuration from the unified
  # configuration system. Handles errors gracefully to avoid blocking
  # application startup.
  #
  # Configuration includes:
  # - API keys for all supported providers
  # - Default models for text, embedding, and image generation
  # - Connection timeouts and retry settings
  # - Logging configuration
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def configure_rubyllm
    RubyLLM.configure do |config|
      # API Keys - use the existing ai_api_key method that checks environment variables
      config.openai_api_key = ai_api_key(:openai)
      config.gemini_api_key = ai_api_key(:gemini)
      config.anthropic_api_key = ai_api_key(:anthropic)
      config.deepseek_api_key = ai_api_key(:deepseek)

      # Custom endpoint
      config.openai_api_base = fetch(:ai, :rubyllm, :openai_api_base)

      # Default models
      config.default_model = fetch(:ai, :rubyllm, :default_model)
      config.default_embedding_model = fetch(:ai, :rubyllm, :default_embedding_model)
      config.default_image_model = fetch(:ai, :rubyllm, :default_image_model)

      # Connection settings
      config.request_timeout = fetch(:ai, :rubyllm, :request_timeout)
      config.max_retries = fetch(:ai, :rubyllm, :max_retries)
      config.retry_interval = fetch(:ai, :rubyllm, :retry_interval)
      config.retry_backoff_factor = fetch(:ai, :rubyllm, :retry_backoff_factor)
      config.retry_interval_randomness = fetch(:ai, :rubyllm, :retry_interval_randomness)

      # Logging settings
      log_file = fetch(:ai, :rubyllm, :log_file)
      config.log_file = log_file unless log_file.nil?
      config.log_level = fetch(:ai, :rubyllm, :log_level)&.to_sym || :info
      config.log_assume_model_exists = fetch(:ai, :rubyllm, :log_assume_model_exists)
    end
  rescue StandardError => e
    # Can't use BlueprintsCLI.logger here as it may not be initialized yet
    warn "Error configuring RubyLLM: #{e.message}"
  end

  # Configure legacy OpenAI gem with settings from unified config system
  #
  # Configures the legacy OpenAI gem if it's available in the application.
  # This provides backward compatibility for code that uses the OpenAI gem
  # directly rather than through RubyLLM.
  #
  # Only configures the gem if it's actually loaded to avoid dependency
  # issues in environments where it's not needed.
  #
  # @return [void]
  #
  # @since 0.1.0
  # @api private
  def configure_openai_gem
    return unless defined?(OpenAI)

    OpenAI.configure do |config|
      # Use environment variables directly for OpenAI gem
      access_token = ENV['OPENAI_ACCESS_TOKEN'] || ai_api_key(:openai)
      base_uri = ENV['OPENAI_BASE_URI']

      config.access_token = access_token if access_token
      config.uri_base = base_uri if base_uri
      config.log_errors = fetch(:ai, :openai, :log_errors, default: true)
    end
  rescue StandardError => e
    # Can't use BlueprintsCLI.logger here as it may not be initialized yet
    warn "Error configuring OpenAI gem: #{e.message}"
  end
end
