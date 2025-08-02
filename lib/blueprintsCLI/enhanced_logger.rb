# frozen_string_literal: true

require 'forwardable'

module BlueprintsCLI
  # EnhancedLogger provides context-aware logging by wrapping TTY::Logger
  # and automatically capturing class/method information from the call stack.
  #
  # This logger maintains backward compatibility with existing logging calls
  # while adding rich context information including class names, method names,
  # file paths, and line numbers.
  #
  # @example Basic usage
  #   logger = EnhancedLogger.new(base_logger)
  #   logger.info("Processing data")  # Automatically includes context
  #
  # @example With custom context
  #   logger.info("Custom message", class: "MyClass", method: "my_method")
  class EnhancedLogger
    # Delegate most methods to the underlying TTY::Logger instance
    extend Forwardable

    def_delegators :@base_logger, :level, :level=, :add_type, :handlers, :handlers=

    # Standard log levels that should include context
    LOG_METHODS = %i[debug info warn error fatal success failure tip step].freeze

    # Initialize the enhanced logger wrapper
    #
    # @param base_logger [TTY::Logger] The underlying TTY::Logger instance
    # @param context_enabled [Boolean] Whether to automatically capture context
    # @param context_detail_level [Symbol] Level of detail for context (:minimal, :standard, :full)
    # @param context_cache_size [Integer] Maximum size of the context cache
    def initialize(base_logger, context_enabled: true, context_detail_level: :full,
                   context_cache_size: 1000)
      @base_logger = base_logger
      @context_enabled = context_enabled
      @context_detail_level = context_detail_level
      @context_cache_size = context_cache_size
      @context_cache = {}

      # Define enhanced logging methods that include context
      LOG_METHODS.each do |method|
        define_singleton_method(method) do |message = nil, **data|
          enhanced_log(method, message, **data)
        end
      end
    end

    # Enable or disable automatic context capture
    #
    # @param enabled [Boolean] Whether to capture context automatically
    attr_writer :context_enabled

    # Check if context capture is enabled
    #
    # @return [Boolean] True if context capture is enabled
    def context_enabled?
      @context_enabled
    end

    private

    # Enhanced logging method that adds context information
    #
    # @param level [Symbol] The log level method to call
    # @param message [String] The log message
    # @param data [Hash] Additional structured data
    def enhanced_log(level, message = nil, **data)
      # Add context information if enabled and not already provided
      if @context_enabled && !data.key?(:class) && !data.key?(:method)
        context = extract_context
        data = data.merge(context) if context
      end

      # Call the original logging method with enhanced data
      if message
        @base_logger.public_send(level, message, **data)
      else
        @base_logger.public_send(level, **data)
      end
    end

    # Extract class and method context from the call stack
    #
    # @param skip_frames [Integer] Number of stack frames to skip
    # @return [Hash, nil] Context hash with class, method, file, line info
    def extract_context(skip_frames = 3)
      # Get caller information, skipping internal frames
      caller_info = caller_locations(skip_frames, 1)&.first
      return nil unless caller_info

      # Cache key for performance optimization
      cache_key = "#{caller_info.path}:#{caller_info.lineno}"
      return @context_cache[cache_key] if @context_cache[cache_key]

      # Extract method name from the caller
      method_name = extract_method_name(skip_frames + 1)

      # Extract class name by examining the call stack
      class_name = extract_class_name(skip_frames + 1)

      # Build context based on detail level
      context = build_context_by_level(class_name, method_name, caller_info)

      # Cache the result for performance (with size limit)
      if context&.any?
        manage_cache_size
        @context_cache[cache_key] = context
      end

      context&.any? ? context : nil
    end

    # Extract method name from caller stack
    #
    # @param skip_frames [Integer] Number of frames to skip
    # @return [String, nil] The method name or nil if not found
    def extract_method_name(skip_frames)
      # Get the method name from caller
      caller_line = caller(skip_frames, 1)&.first
      return nil unless caller_line

      # Extract method name using regex (handles various formats)
      method_match = caller_line[/`([^']*)'/, 1]
      method_match unless method_match == 'rescue in <main>' || method_match&.start_with?('<')
    end

    # Extract class name by walking up the call stack
    #
    # @param skip_frames [Integer] Number of frames to skip
    # @return [String, nil] The class name or nil if not found
    def extract_class_name(skip_frames)
      # Look through several frames to find a class context
      (skip_frames..(skip_frames + 10)).each do |frame_index|
        location = caller_locations(frame_index, 1)&.first
        break unless location

        # Try to determine class from the file path and method context
        file_path = location.path

        # Skip internal Ruby/gem files
        next if file_path.include?('/gems/') || file_path.include?('/ruby/')

        # Look for BlueprintsCLI classes in the path
        next unless file_path.include?('blueprintsCLI')

        # Extract class name from file path
        relative_path = file_path.split('blueprintsCLI').last
        if relative_path&.include?('commands')
          # Handle command classes
          return extract_command_class_name(relative_path)
        elsif relative_path&.include?('actions')
          # Handle action classes
          return extract_action_class_name(relative_path)
        elsif relative_path&.include?('services')
          # Handle service classes
          return extract_service_class_name(relative_path)
        end
      end

      nil
    end

    # Extract command class name from file path
    #
    # @param path [String] Relative path within blueprintsCLI
    # @return [String, nil] The command class name
    def extract_command_class_name(path)
      return unless path.include?('commands') && path.end_with?('.rb')

      filename = File.basename(path, '.rb')
      # Convert snake_case to CamelCase and add Command suffix
      class_base = filename.split('_').map(&:capitalize).join
      "BlueprintsCLI::Commands::#{class_base}" unless class_base == 'BaseCommand'
    end

    # Extract action class name from file path
    #
    # @param path [String] Relative path within blueprintsCLI
    # @return [String, nil] The action class name
    def extract_action_class_name(path)
      return unless path.include?('actions') && path.end_with?('.rb')

      filename = File.basename(path, '.rb')
      class_base = filename.split('_').map(&:capitalize).join
      "BlueprintsCLI::Actions::#{class_base}"
    end

    # Extract service class name from file path
    #
    # @param path [String] Relative path within blueprintsCLI
    # @return [String, nil] The service class name
    def extract_service_class_name(path)
      return unless path.include?('services') && path.end_with?('.rb')

      filename = File.basename(path, '.rb')
      class_base = filename.split('_').map(&:capitalize).join
      "BlueprintsCLI::Services::#{class_base}"
    end

    # Build context hash based on configured detail level
    #
    # @param class_name [String, nil] The extracted class name
    # @param method_name [String, nil] The extracted method name
    # @param caller_info [Thread::Backtrace::Location] Caller location info
    # @return [Hash] Context hash with appropriate level of detail
    def build_context_by_level(class_name, method_name, caller_info)
      case @context_detail_level
      when :minimal
        # Just class and method
        { class: class_name, method: method_name }.compact
      when :standard
        # Class, method, and file
        {
          class: class_name,
          method: method_name,
          file: File.basename(caller_info.path)
        }.compact
      when :full
        # Full context with line numbers
        {
          class: class_name,
          method: method_name,
          file: File.basename(caller_info.path),
          line: caller_info.lineno,
          path: caller_info.path
        }.compact
      else
        # Default to standard if unknown level
        {
          class: class_name,
          method: method_name,
          file: File.basename(caller_info.path)
        }.compact
      end
    end

    # Manage cache size to prevent memory bloat
    def manage_cache_size
      return unless @context_cache.size >= @context_cache_size

      # Remove oldest 25% of entries when cache is full
      entries_to_remove = @context_cache_size / 4
      @context_cache = @context_cache.to_a.drop(entries_to_remove).to_h
    end
  end
end
