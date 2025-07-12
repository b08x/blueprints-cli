# frozen_string_literal: true

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
      file_logging_enabled = app_config.fetch(:logger, :file_logging) || false
      log_file_path = app_config.fetch(:logger, :file_path) || default_log_path
      file_log_level = app_config.fetch(:logger, :file_level)&.to_sym || :debug

      @@instance = TTY::Logger.new do |config|
        # Configure handlers (console and optional file)
        handlers = []
        handlers << configure_console_handler(log_level)
        handlers << configure_file_handler(log_file_path, file_log_level) if file_logging_enabled

        config.handlers = handlers
      end

      # Add custom log types after initialization with styling
      # Use try-catch to handle any conflicts with built-in types
      begin
        @@instance.add_type(:success, { level: :info, symbol: '✅', color: :green })
      rescue TTY::Logger::Error
        # Type already exists, skip
      end

      begin
        @@instance.add_type(:failure, { level: :error, symbol: '❌', color: :red })
      rescue TTY::Logger::Error
        # Type already exists, skip
      end

      begin
        @@instance.add_type(:tip, { level: :info, symbol: '💡', color: :cyan })
      rescue TTY::Logger::Error
        # Type already exists, skip
      end

      begin
        @@instance.add_type(:step, { level: :info, symbol: '🚀', color: :blue })
      rescue TTY::Logger::Error
        # Type already exists, skip
      end

      @@instance
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
