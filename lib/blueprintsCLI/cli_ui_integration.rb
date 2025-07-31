# frozen_string_literal: true

# Load CLI-UI with a proper namespace
begin
  require_relative '../cli/ui'
rescue LoadError
  # Fallback to the gem version if available
  require 'cli/ui'
end

module BlueprintsCLI
  # CLI-UI Integration module for BlueprintsCLI
  # Provides enhanced interactive interface with autocomplete and visual improvements
  module CLIUIIntegration
    # Initialize CLI-UI with BlueprintsCLI-specific settings
    def self.initialize!
      # Configure color scheme to match BlueprintsCLI
      ::CLI::UI.enable_color = $stdout.tty?
      ::CLI::UI.enable_cursor = $stdout.tty? && ENV['CI'].nil?

      # Set default frame style for consistent branding
      ::CLI::UI.frame_style = :box

      # Set up custom instruction colors to match BlueprintsCLI theme
      ::CLI::UI::Prompt.instructions_color = :cyan
    end

    # Enhanced frame wrapper that integrates with BlueprintsCLI logger
    def self.frame(text, color: :cyan, **options, &block)
      ::CLI::UI.frame(text, color: color, **options, &block)
    end

    # Enhanced prompt wrapper with BlueprintsCLI integration
    def self.ask(question, **options)
      ::CLI::UI.ask(question, **options)
    end

    # Enhanced select with better visual styling
    def self.select(question, options = nil, **kwargs, &)
      if block_given?
        ::CLI::UI.ask(question, **kwargs, &)
      else
        ::CLI::UI.ask(question, options: options, **kwargs)
      end
    end

    # Confirm with BlueprintsCLI styling
    def self.confirm(question, default: true)
      ::CLI::UI.confirm(question, default: default)
    end

    # Display formatted text with CLI-UI formatting
    def self.puts(text, **options)
      ::CLI::UI.puts(text, **options)
    end

    # Display formatted text without frame prefix
    def self.raw_puts(text)
      ::CLI::UI.raw { puts text }
    end

    # Create a spinner with BlueprintsCLI styling
    def self.spinner(title, ...)
      ::CLI::UI.spinner(title, ...)
    end
  end
end
