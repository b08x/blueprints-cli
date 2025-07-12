# frozen_string_literal: true

module BlueprintsCLI
  module Commands
    ##
    # ConfigCommand handles all configuration management operations for BlueprintsCLI.
    # This command provides a comprehensive interface for setting up, viewing,
    # editing, validating, and resetting the application configuration.
    #
    # The command follows a subcommand pattern where the first argument determines
    # the specific configuration operation to perform. This design allows for a
    # clean separation of concerns and provides a user-friendly interface for
    # configuration management.
    #
    # @example Setup new configuration
    #   BlueprintsCLI::Commands::ConfigCommand.new({}).execute('setup')
    #
    # @example Show current configuration
    #   BlueprintsCLI::Commands::ConfigCommand.new({}).execute('show')
    class ConfigCommand < BaseCommand
      ##
      # Provides a description of what this command does, used in help text
      #
      # @return [String] A description of the command's purpose
      def self.description
        'Manage BlueprintsCLI configuration settings'
      end

      ##
      # Initializes a new ConfigCommand instance
      #
      # @param [Hash] options The options to configure the command
      def initialize(options)
        super
        @prompt = TTY::Prompt.new
      end

      ##
      # Executes the configuration command with the provided arguments
      #
      # This method routes to the appropriate handler based on the subcommand provided.
      # If no subcommand is provided, it defaults to the setup handler.
      #
      # @param [Array<String>] args The arguments to pass to the command
      # @return [Boolean] true if the command executed successfully, false otherwise
      #
      # @example Execute with setup subcommand
      #   command = ConfigCommand.new({})
      #   command.execute(['setup'])
      def execute(*args)
        subcommand = args.shift

        case subcommand
        when 'setup', nil
          handle_setup
        when 'show'
          handle_show
        when 'edit'
          handle_edit
        when 'reset'
          handle_reset
        when 'validate'
          handle_validate
        when 'help'
          show_help
        else
          puts "❌ Unknown subcommand: #{subcommand}".colorize(:red)
          show_help
          false
        end
      end

      private

      ##
      # Handles the configuration setup process
      #
      # This method guides the user through an interactive setup process to configure
      # BlueprintsCLI for their environment. It loads the configuration module and
      # initiates the interactive setup procedure.
      #
      # @return [Boolean] true if setup was successful, false otherwise
      #
      # @example Run the setup handler
      #   command = ConfigCommand.new({})
      #   command.send(:handle_setup)
      def handle_setup
        puts '🔧 BlueprintsCLI Configuration Setup'.colorize(:blue)
        puts '=' * 40

        begin
          require_relative '../configuration'
          config = BlueprintsCLI::Configuration.new
          success = config.interactive_setup

          if success
            puts '✅ Configuration setup completed successfully!'.colorize(:green)
            true
          else
            puts '⚠️  Configuration setup completed with warnings.'.colorize(:yellow)
            false
          end
        rescue StandardError => e
          puts "❌ Error during configuration setup: #{e.message}".colorize(:red)
          puts "   File: #{e.backtrace.first}" if ENV['DEBUG']
          false
        end
      end

      ##
      # Displays the current configuration settings
      #
      # This method loads and displays the current configuration in a formatted way,
      # showing each configuration section with its values. If no configuration is
      # found, it informs the user and suggests running the setup command.
      #
      # @return [Boolean] true if the configuration was displayed successfully, false otherwise
      #
      # @example Show current configuration
      #   command = ConfigCommand.new({})
      #   command.send(:handle_show)
      def handle_show
        puts '📋 Current Configuration'.colorize(:blue)
        puts '=' * 25

        begin
          require_relative '../configuration'
          config = BlueprintsCLI::Configuration.new
          config_hash = config.config.to_hash

          if config_hash.empty?
            puts "⚠️  No configuration found. Run 'config setup' to create one.".colorize(:yellow)
            return false
          end

          display_config_section('Paths', config_hash['paths']) if config_hash['paths']
          display_config_section('Display', config_hash['display']) if config_hash['display']
          display_config_section('Restic', config_hash['restic']) if config_hash['restic']
          display_config_section('Terminal', config_hash['terminal']) if config_hash['terminal']
          display_config_section('Logger', config_hash['logger']) if config_hash['logger']

          true
        rescue StandardError => e
          puts "❌ Error reading configuration: #{e.message}".colorize(:red)
          false
        end
      end

      ##
      # Provides an interactive editor for modifying configuration sections
      #
      # This method allows users to select and edit specific configuration sections
      # through an interactive menu. Users can choose to edit individual sections or
      # run through the full setup process again.
      #
      # @return [Boolean] true if the configuration was edited successfully, false otherwise
      #
      # @example Edit configuration
      #   command = ConfigCommand.new({})
      #   command.send(:handle_edit)
      def handle_edit
        puts '✏️  Interactive Configuration Editor'.colorize(:blue)
        puts '=' * 35

        begin
          require_relative '../configuration'
          config = BlueprintsCLI::Configuration.new

          section = @prompt.select('Which section would you like to edit?') do |menu|
            menu.choice '📁 Paths (directories and repositories)', :paths
            menu.choice '🎨 Display settings', :display
            menu.choice '📦 Restic backup settings', :restic
            menu.choice '💻 Terminal settings', :terminal
            menu.choice '📝 Logger settings', :logger
            menu.choice '🔄 Full setup (all sections)', :all
            menu.choice '❌ Cancel', :cancel
          end

          return true if section == :cancel

          case section
          when :paths
            config.send(:configure_paths)
          when :display
            config.send(:configure_display)
          when :restic
            config.send(:configure_restic)
          when :terminal
            config.send(:configure_terminals)
          when :logger
            config.send(:configure_logger)
          when :all
            config.interactive_setup
          end

          config.send(:save_config)
          puts '✅ Configuration updated successfully!'.colorize(:green)
          true
        rescue StandardError => e
          puts "❌ Error editing configuration: #{e.message}".colorize(:red)
          false
        end
      end

      ##
      # Resets the configuration by deleting the configuration file
      #
      # This method prompts the user for confirmation before deleting the configuration
      # file. If the file doesn't exist, it informs the user.
      #
      # @return [Boolean] true if the configuration was reset successfully or didn't exist, false otherwise
      #
      # @example Reset configuration
      #   command = ConfigCommand.new({})
      #   command.send(:handle_reset)
      def handle_reset
        puts '🔄 Reset Configuration'.colorize(:blue)
        puts '=' * 22

        config_file = File.expand_path('~/.config/BlueprintsCLI/config.yml')

        if File.exist?(config_file)
          confirmed = @prompt.yes?('⚠️  This will delete your current configuration. Are you sure?')
          return false unless confirmed

          begin
            File.delete(config_file)
            puts '✅ Configuration file deleted successfully.'.colorize(:green)
            puts "💡 Run 'config setup' to create a new configuration.".colorize(:cyan)
            true
          rescue StandardError => e
            puts "❌ Error deleting configuration file: #{e.message}".colorize(:red)
            false
          end
        else
          puts "ℹ️  No configuration file found at #{config_file}".colorize(:blue)
          true
        end
      end

      ##
      # Validates the current configuration
      #
      # This method checks the validity of the current configuration, particularly
      # focusing on verifying that required external tools and settings are available.
      #
      # @return [Boolean] true if the configuration is valid, false otherwise
      #
      # @example Validate configuration
      #   command = ConfigCommand.new({})
      #   command.send(:handle_validate)
      def handle_validate
        puts '🔍 Validating Configuration'.colorize(:blue)
        puts '=' * 26

        begin
          require_relative '../configuration'
          config = BlueprintsCLI::Configuration.new

          # Test terminal command
          puts '📡 Checking terminal availability...'.colorize(:cyan)
          terminals_valid = config.send(:validate_terminal_command)

          if terminals_valid
            puts '✅ Configuration validation passed!'.colorize(:green)
          else
            puts '⚠️  Configuration validation completed with warnings.'.colorize(:yellow)
          end

          true
        rescue TTY::Config::ValidationError => e
          puts "❌ Configuration validation failed: #{e.message}".colorize(:red)
          false
        rescue StandardError => e
          puts "❌ Error during validation: #{e.message}".colorize(:red)
          false
        end
      end

      ##
      # Displays a configuration section with proper formatting
      #
      # This helper method formats and displays a configuration section with
      # appropriate coloring and indentation based on the data type.
      #
      # @param [String] title The title of the section to display
      # @param [Hash, Array, Object] data The configuration data to display
      #
      # @example Display a configuration section
      #   command = ConfigCommand.new({})
      #   command.send(:display_config_section, "Paths", { home: "/home/user" })
      def display_config_section(title, data)
        puts "\n#{title}:".colorize(:cyan)
        case data
        when Hash
          data.each do |key, value|
            puts "  #{key}: #{format_value(value)}"
          end
        when Array
          data.each_with_index do |item, i|
            puts "  #{i + 1}. #{format_value(item)}"
          end
        else
          puts "  #{format_value(data)}"
        end
      end

      ##
      # Formats a configuration value for display
      #
      # This helper method applies appropriate formatting and coloring to configuration
      # values based on their type. Special handling is provided for command/args hashes.
      #
      # @param [Object] value The value to format
      # @return [String] The formatted value with appropriate coloring
      #
      # @example Format a simple value
      #   command = ConfigCommand.new({})
      #   command.send(:format_value, "/home/user")
      #
      # @example Format a command hash
      #   command = ConfigCommand.new({})
      #   command.send(:format_value, { command: "ls", args: "-la" })
      def format_value(value)
        case value
        when Hash
          if value.key?('command') && value.key?('args')
            "#{value['command']} #{value['args']}".colorize(:yellow)
          else
            value.inspect.colorize(:yellow)
          end
        when String
          value.colorize(:yellow)
        else
          value.to_s.colorize(:yellow)
        end
      end

      ##
      # Displays help information for the configuration command
      #
      # This method outputs detailed help information including available subcommands,
      # configuration sections, file information, examples, and tips.
      #
      # @example Show help
      #   command = ConfigCommand.new({})
      #   command.send(:show_help)
      def show_help
        puts <<~HELP
          Configuration Management Commands:

          🔧 Setup & Management:
            config setup                         Interactive configuration setup (default)
            config show                          Display current configuration
            config edit                          Edit specific configuration sections
            config reset                         Delete configuration file
            config validate                      Validate configuration and check dependencies

          📋 Configuration Sections:
            • Paths: Home directory, restic mount point, repository paths
            • Display: Time format and output preferences#{'  '}
            • Restic: Backup mounting timeout and settings
            • Terminal: Default terminal emulator command and arguments
            • Logger: Log levels, file logging, and output preferences

          💾 Configuration File:
            Location: ~/.config/BlueprintsCLI/config.yml
            Format: YAML with hierarchical sections

          Examples:
            config                               # Run interactive setup
            config show                          # View current settings
            config edit                          # Edit specific sections
            config validate                      # Check configuration validity
            config reset                         # Start fresh

          💡 Tips:
            • Use 'config setup' for first-time configuration
            • Use 'config edit' to modify specific sections only
            • Use 'config validate' to check if external tools are available

        HELP
      end
    end
  end
end
