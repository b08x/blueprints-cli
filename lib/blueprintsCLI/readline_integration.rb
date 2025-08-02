# frozen_string_literal: true

require 'readline'

module BlueprintsCLI
  # ReadlineIntegration module provides centralized readline setup and autocomplete functionality
  # It manages the integration between Ruby's readline library and our custom autocomplete system
  module ReadlineIntegration
    extend self

    # Initialize readline with autocomplete support
    def setup_readline(autocomplete_handler)
      return false unless readline_available?

      @autocomplete_handler = autocomplete_handler
      configure_completion_proc
      configure_readline_settings
      setup_history_management

      # Mark the autocomplete handler as readline ready
      @autocomplete_handler.readline_ready! if @autocomplete_handler.respond_to?(:readline_ready!)

      safe_log_debug('Readline autocomplete initialized successfully')
      true
    rescue StandardError => e
      safe_log_warn("Failed to initialize readline autocomplete: #{e.message}")
      false
    end

    # Get user input with readline support and history
    def readline_input(prompt = '> ', add_to_history = true)
      return fallback_input(prompt) unless readline_available? && @autocomplete_handler

      begin
        input = Readline.readline(prompt, add_to_history)
        input&.strip
      rescue Interrupt
        raise
      rescue StandardError => e
        safe_log_debug("Readline input failed: #{e.message}")
        fallback_input(prompt)
      end
    end

    # Check if readline functionality is available
    def readline_available?
      defined?(Readline) && Readline.respond_to?(:readline)
    end

    # Get current autocomplete handler
    def autocomplete_handler
      @autocomplete_handler
    end

    # Reset readline configuration
    def reset_readline
      return unless readline_available?

      Readline.completion_proc = nil
      Readline.completion_append_character = ' '
      @autocomplete_handler = nil
    end

    private

    def configure_completion_proc
      Readline.completion_proc = proc do |input|
        completions = @autocomplete_handler.completions_for(input)
        BlueprintsCLI.logger.debug("Generated #{completions.size} completions for: '#{input}'")
        completions
      rescue StandardError => e
        BlueprintsCLI.logger.debug("Completion error: #{e.message}")
        []
      end
    end

    def configure_readline_settings
      # Configure completion behavior
      Readline.completion_append_character = ' '

      # Set up history file if supported
      setup_history_file if Readline.respond_to?(:HISTORY)
    end

    def setup_history_management
      return unless Readline.respond_to?(:HISTORY)

      # Limit history size to prevent memory issues
      max_history_size = 1000

      # Clear old history if it gets too long
      return unless Readline::HISTORY.length > max_history_size

      excess = Readline::HISTORY.length - max_history_size
      excess.times { Readline::HISTORY.shift }
    end

    def setup_history_file
      history_file = File.join(Dir.home, '.blueprintscli_history')

      # Load existing history
      if File.exist?(history_file)
        File.readlines(history_file).each { |line| Readline::HISTORY << line.chomp }
      end

      # Save history on exit
      at_exit do
        File.open(history_file, 'w') do |f|
          Readline::HISTORY.to_a.last(1000).each { |line| f.puts(line) }
        end
      end
    rescue StandardError => e
      safe_log_debug("History file setup failed: #{e.message}")
    end

    def fallback_input(prompt)
      print prompt
      $stdin.gets&.chomp&.strip
    end

    # Safe logging methods that won't fail if logger isn't available
    def safe_log_debug(message)
      if defined?(BlueprintsCLI) && BlueprintsCLI.respond_to?(:logger)
        BlueprintsCLI.logger.debug(message)
      end
    rescue StandardError
      # Silently ignore logging errors during initialization
    end

    def safe_log_warn(message)
      if defined?(BlueprintsCLI) && BlueprintsCLI.respond_to?(:logger)
        BlueprintsCLI.logger.warn(message)
      end
    rescue StandardError
      # Silently ignore logging errors during initialization
    end
  end
end
