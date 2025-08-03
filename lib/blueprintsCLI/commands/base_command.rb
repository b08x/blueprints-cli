# frozen_string_literal: true

module BlueprintsCLI
  module Commands
    ##
    # BaseCommand serves as the abstract foundation for all command classes in BlueprintsCLI.
    # It provides common functionality including command naming, logging capabilities,
    # and establishes the interface that all concrete command classes must implement.
    #
    # Concrete command classes should inherit from BaseCommand and implement the +execute+ method
    # to perform their specific operations while gaining access to standardized logging
    # and command metadata functionality.
    #
    # @abstract Subclasses must implement {#execute} to be functional
    class BaseCommand
      ##
      # Generates a standardized command name based on the class name.
      #
      # Derives the command name by taking the last part of the class name (after any
      # namespace) and removing the trailing 'Command' if present, then downcasing the result.
      #
      # @return [String] the generated command name
      # @example For a class named BlueprintsCLI::Commands::InstallCommand
      #   command_name #=> "install"
      def self.command_name
        name.split('::').last.gsub(/Command$/, '').downcase
      end

      ##
      # Provides a default description for the command.
      #
      # Generates a basic description using the command name. Subclasses should override
      # this method to provide more specific information about what the command does.
      #
      # @return [String] the command description
      # @example For a command named "install"
      #   description #=> "Description for install"
      def self.description
        "Description for #{command_name}"
      end

      ##
      # Initializes a new command instance.
      #
      # @param [Hash] options the configuration options for this command
      def initialize(options)
        @options = options
      end

      ##
      # Executes the command's primary functionality.
      #
      # This method must be implemented by concrete command subclasses to perform
      # their specific operations. The base implementation raises an error to enforce
      # this requirement.
      #
      # @param [Array<Object>] args variable arguments that may be needed for command execution
      # @raise [NotImplementedError] if the method is not overridden in a subclass
      def execute(*args)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      protected

      ##
      # Provides access to the BlueprintsCLI logger instance with automatic context.
      # The enhanced logger will automatically capture the calling class and method.
      #
      # @return [EnhancedLogger] the configured enhanced logger instance
      def logger
        @logger ||= create_context_logger
      end

      private

      ##
      # Creates a context-aware logger that includes class and method information.
      #
      # @return [EnhancedLogger] logger with context information
      def create_context_logger
        BlueprintsCLI.logger
      end

      ##
      # Logs a success message.
      #
      # @param [String] message the success message to log
      # @param [Hash] data additional data to include with the log message
      def log_success(message, **data)
        BlueprintsCLI.logger.success(message, **data)
      end

      ##
      # Logs a failure message.
      #
      # @param [String] message the failure message to log
      # @param [Hash] data additional data to include with the log message
      def log_failure(message, **data)
        BlueprintsCLI.logger.failure(message, **data)
      end

      ##
      # Logs a warning message.
      #
      # @param [String] message the warning message to log
      # @param [Hash] data additional data to include with the log message
      def log_warning(message, **data)
        BlueprintsCLI.logger.warn(message, **data)
      end

      ##
      # Logs a tip message.
      #
      # @param [String] message the tip message to log
      # @param [Hash] data additional data to include with the log message
      def log_tip(message, **data)
        BlueprintsCLI.logger.tip(message, **data)
      end

      ##
      # Logs a step message, typically used for progress tracking.
      #
      # @param [String] message the step message to log
      # @param [Hash] data additional data to include with the log message
      def log_step(message, **data)
        BlueprintsCLI.logger.step(message, **data)
      end

      ##
      # Logs an informational message.
      #
      # @param [String] message the informational message to log
      # @param [Hash] data additional data to include with the log message
      def log_info(message, **data)
        BlueprintsCLI.logger.info(message, **data)
      end

      ##
      # Logs a debug message.
      #
      # @param [String] message the debug message to log
      # @param [Hash] data additional data to include with the log message
      def log_debug(message, **data)
        BlueprintsCLI.logger.debug(message, **data)
      end

      ##
      # Logs an error message.
      #
      # @param [String] message the error message to log
      # @param [Hash] data additional data to include with the log message
      def log_error(message, **data)
        BlueprintsCLI.logger.error(message, **data)
      end
    end
  end
end
