# frozen_string_literal: true

require 'ruby_llm'
require_relative 'enhanced_logger'

module BlueprintsCLI
  # Centralized logger module for the BlueprintsCLI application.
  # Encapsulates TTY::Logger configuration and provides a singleton instance.
  module Logger
    # Class variable to hold the singleton logger instance.
    @@instance = nil

    # Retrieves the singleton logger instance.
    # On first call, it initializes and configures the logger.
    #
    # @return [TTY::Logger] The configured logger instance.
    def self.instance
      return @@instance if @@instance

      # Load user configuration for the logger
      app_config = BlueprintsCLI::Configuration.new
      log_level = app_config.fetch(:logger, :level)&.to_sym || :info
      console_logging_enabled = app_config.fetch(:logger, :console_logging, default: true)
      file_logging_enabled = app_config.fetch(:logger, :file_logging) || false
      log_file_path = app_config.fetch(:logger, :file_path) || default_log_path
      file_log_level = app_config.fetch(:logger, :file_level)&.to_sym || :debug

      base_logger = TTY::Logger.new do |config|
        # Configure handlers (console and optional file)
        handlers = []
        handlers << configure_console_handler(log_level) if console_logging_enabled
        handlers << configure_file_handler(log_file_path, file_log_level) if file_logging_enabled

        config.handlers = handlers
      end

      # Add custom log types after initialization with styling
      # Use try-catch to handle any conflicts with built-in types
      begin
        base_logger.add_type(:success, { level: :info, symbol: '✅', color: :green })
      rescue TTY::Logger::Error
        # Type already exists, skip
      end

      begin
        base_logger.add_type(:failure, { level: :error, symbol: '❌', color: :red })
      rescue TTY::Logger::Error
        # Type already exists, skip
      end

      begin
        base_logger.add_type(:tip, { level: :info, symbol: '💡', color: :cyan })
      rescue TTY::Logger::Error
        # Type already exists, skip
      end

      begin
        base_logger.add_type(:step, { level: :info, symbol: '🚀', color: :blue })
      rescue TTY::Logger::Error
        # Type already exists, skip
      end

      # Check context logging configuration options
      context_enabled = app_config.fetch(:logger, :context_enabled, default: true)
      context_detail_level = app_config.fetch(:logger, :context_detail_level,
                                              default: 'full')&.to_sym || :full
      context_cache_size = app_config.fetch(:logger, :context_cache_size, default: 1000) || 1000

      # Wrap the base logger with enhanced context-aware functionality
      @@instance = EnhancedLogger.new(
        base_logger,
        context_enabled: context_enabled,
        context_detail_level: context_detail_level,
        context_cache_size: context_cache_size
      )

      @@instance
    end

    # Logs a structured, user-friendly error for AI-related exceptions.
    #
    # @param error [StandardError] The exception to log.
    def self.ai_error(error)
      instance.failure("AI Error: #{error.message}")
      case error
      when RubyLLM::AuthenticationError
        instance.tip("Check your API key and provider settings in `config.yml`.")
      when RubyLLM::ConfigurationError
        instance.tip("Review your AI configuration in `config.yml` for missing or invalid values.")
      when RubyLLM::RateLimitError
        instance.tip("You have exceeded your API quota. Please check your plan and usage limits.")
      when RubyLLM::APIConnectionError
        instance.tip("Could not connect to the AI provider. Check your network connection.")
      when RubyLLM::InvalidRequestError
        instance.warn("The request to the AI provider was invalid. This may be a bug.")
        instance.debug(error.backtrace.join("\n")) if ENV['DEBUG']
      else
        instance.warn("An unexpected error occurred while communicating with the AI provider.")
        instance.debug(error.backtrace.join("\n")) if ENV['DEBUG']
      end
    end

    # Reset the singleton instance (useful for testing)
    def self.reset!
      @@instance = nil
    end

    private

    # Configures the console handler with custom styles.
    #
    # @param level [Symbol] The minimum log level for the console.
    # @return [Array] The handler configuration array for TTY::Logger.
    def self.configure_console_handler(level)
      [
        :console,
        {
          level: level,
          output: $stderr, # Log to stderr to separate from program output
          styles: {
            info: { symbol: 'ℹ️', color: :blue },
            debug: { symbol: '🐞', color: :magenta },
            error: { symbol: '❌', color: :red },
            warn: { symbol: '⚠️', color: :yellow },
            fatal: { symbol: '💀', color: :red, bold: true }
          }
        }
      ]
    end

    # Configures the file stream handler.
    #
    # @param path [String] The path to the log file.
    # @param level [Symbol] The minimum log level for the file.
    # @return [Array] The handler configuration array for TTY::Logger.
    def self.configure_file_handler(path, level)
      # Ensure the directory for the log file exists
      FileUtils.mkdir_p(File.dirname(path))

      [
        :stream,
        {
          level: level,
          output: File.open(path, 'a'),
          formatter: :json # Use JSON format for structured logging
        }
      ]
    end

    # Determines the default path for the log file.
    #
    # @return [String] The absolute path for the log file.
    def self.default_log_path
      # Use XDG Base Directory Specification if available, otherwise fallback
      state_home = ENV['XDG_STATE_HOME'] || File.expand_path('~/.local/state')
      File.join(state_home, 'BlueprintsCLI', 'app.log')
    end
  end
end