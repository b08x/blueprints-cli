# frozen_string_literal: true

module BlueprintsCLI
  module Commands
    # BlueprintCommand provides a comprehensive interface for managing code blueprints
    # with AI-enhanced capabilities. It allows developers to submit, organize,
    # search, and manipulate code blueprints through a command-line interface.
    #
    # The command supports various subcommands for different operations and integrates
    # with AI features for automatic description generation and categorization.
    class BlueprintCommand < BaseCommand
      # Returns a description of what the BlueprintCommand does
      #
      # @return [String] A description of the command's purpose
      def self.description
        'Manage code blueprints with AI-enhanced metadata and vector search capabilities'
      end

      # Initializes a new BlueprintCommand with the given options
      #
      # @param [Hash] options The options to configure the command
      def initialize(options)
        super
        @subcommand = nil
        @args = []
      end

      # Executes the blueprint command with the provided arguments
      #
      # @param [Array<String>] args The arguments to process
      # @return [Boolean, nil] Returns false if the command fails, nil otherwise
      def execute(*args)
        @subcommand = args.shift
        @args = args

        case @subcommand
        when 'submit'
          handle_submit
        when 'list'
          handle_list
        when 'browse'
          handle_browse
        when 'view'
          handle_view
        when 'edit'
          handle_edit
        when 'delete'
          handle_delete
        when 'search'
          handle_search
        when 'export'
          handle_export
        when 'generate'
          handle_generate
        when 'config'
          handle_config
        when 'help', nil
          show_help
        else
          puts "❌ Unknown subcommand: #{@subcommand}".colorize(:red)
          show_help
          false
        end
      end

      private

      # Handles the submission of a new blueprint
      #
      # Accepts either a file path or direct code string as input.
      # Supports automatic description and categorization through AI features.
      #
      # @return [Boolean] Returns false if submission fails due to missing input
      def handle_submit
        input = @args.first

        unless input
          puts '❌ Please provide a file path or code string'.colorize(:red)
          puts 'Usage: blueprint submit <file_path_or_code>'
          return false
        end

        if File.exist?(input)
          puts "📁 Submitting blueprint from file: #{input}".colorize(:blue)
          code = File.read(input)
        else
          puts '📝 Submitting blueprint from code string'.colorize(:blue)
          code = input
        end

        BlueprintsCLI::Actions::Submit.new(
          code: code,
          auto_describe: @options['auto_describe'] != false,
          auto_categorize: @options['auto_categorize'] != false
        ).call
      end

      # Lists available blueprints with optional formatting
      #
      # @return [void] Outputs the list of blueprints to the console
      def handle_list
        format = (@options['format'] || 'table').to_sym
        interactive = @options['interactive'] || false

        BlueprintsCLI::Actions::List.new(
          format: format,
          interactive: interactive
        ).call
      end

      # Provides an interactive browsing experience for blueprints
      #
      # @return [void] Initiates the interactive browsing session
      def handle_browse
        BlueprintsCLI::Actions::List.new(
          interactive: true
        ).call
      end

      # Views a specific blueprint with detailed information
      #
      # @param [String] id The ID of the blueprint to view
      # @option options [Symbol] :format (:detailed) The output format
      # @option options [Boolean] :analyze (false) Whether to include AI analysis
      # @return [Boolean] Returns false if no ID is provided
      def handle_view
        id = @args.first

        unless id
          puts '❌ Please provide a blueprint ID'.colorize(:red)
          puts 'Usage: blueprint view <id>'
          return false
        end

        format = (@options['format'] || 'detailed').to_sym

        BlueprintsCLI::Actions::View.new(
          id: id.to_i,
          format: format,
          with_suggestions: @options['analyze'] || false
        ).call
      end

      # Edits an existing blueprint
      #
      # @param [String] id The ID of the blueprint to edit
      # @return [Boolean] Returns false if no ID is provided
      def handle_edit
        id = @args.first

        unless id
          puts '❌ Please provide a blueprint ID'.colorize(:red)
          puts 'Usage: blueprint edit <id>'
          return false
        end

        BlueprintsCLI::Actions::Edit.new(
          id: id.to_i
        ).call
      end

      # Deletes a blueprint with optional force flag
      #
      # @param [String] id The ID of the blueprint to delete
      # @param [Boolean] force Whether to skip confirmation prompts
      # @return [void] Initiates the delete action
      def handle_delete
        # Check for force flag in arguments
        force = @args.include?('--force')

        # Get ID (first non-flag argument)
        id = @args.find { |arg| !arg.start_with?('--') }

        # If no ID provided, will trigger interactive selection
        BlueprintsCLI::Actions::Delete.new(
          id: id&.to_i,
          force: force
        ).call
      end

      # Searches blueprints based on a query
      #
      # @param [String] query The search query
      # @option options [Integer] :limit (10) The maximum number of results to return
      # @return [Boolean] Returns false if no query is provided
      def handle_search
        query = @args.join(' ')

        if query.empty?
          puts '❌ Please provide a search query'.colorize(:red)
          puts 'Usage: blueprint search <query>'
          return false
        end

        BlueprintsCLI::Actions::Search.new(
          query: query,
          limit: @options['limit'] || 10
        ).call
      end

      # Exports a blueprint to a file
      #
      # @param [String] id The ID of the blueprint to export
      # @param [String] output_path The path to export the blueprint to
      # @return [Boolean] Returns false if no ID is provided
      def handle_export
        id = @args.first
        output_path = @args[1] || @options['output']

        unless id
          puts '❌ Please provide a blueprint ID'.colorize(:red)
          puts 'Usage: blueprint export <id> [output_file]'
          return false
        end

        BlueprintsCLI::Actions::Export.new(
          id: id.to_i,
          output_path: output_path
        ).call
      end

      # Generates code based on natural language input using blueprint context
      #
      # @param [String] prompt The natural language description of code to generate
      # @option options [String] :output_dir ("./generated") The output directory
      # @option options [Integer] :limit (5) Number of blueprints to use as context
      # @option options [Boolean] :force (false) Whether to overwrite existing files
      # @return [Boolean] Returns false if no prompt is provided
      def handle_generate
        prompt = @args.join(' ')

        if prompt.empty?
          puts '❌ Please provide a description of what you want to generate'.colorize(:red)
          puts 'Usage: blueprint generate <description>'
          return false
        end

        output_dir = @options['output_dir'] || @options['output'] || './generated'
        limit = (@options['limit'] || 5).to_i
        force = @options['force'] || false

        puts "🚀 Generating code based on: #{prompt}".colorize(:blue)
        puts "📁 Output directory: #{output_dir}".colorize(:cyan)
        puts "🔍 Using #{limit} relevant blueprints as context".colorize(:cyan)

        result = BlueprintsCLI::Actions::Generate.new(
          prompt: prompt,
          output_dir: output_dir,
          limit: limit,
          force: force
        ).call

        if result[:success]
          puts "\n✅ Code generation completed successfully!".colorize(:green)
          puts "📊 Generated #{result[:generated_files].length} files".colorize(:green)

          result[:generated_files].each do |file_result|
            if file_result[:success]
              puts "  ✅ #{file_result[:name]} (#{file_result[:language]})".colorize(:green)
            else
              puts "  ❌ #{file_result[:name]} - #{file_result[:error]}".colorize(:red)
            end
          end

          unless result[:relevant_blueprints].empty?
            puts "\n📚 Used blueprints for context: #{result[:relevant_blueprints].join(', ')}".colorize(:cyan)
          end
        else
          puts "❌ Code generation failed: #{result[:error]}".colorize(:red)
          false
        end
      end

      # Manages blueprint configuration
      #
      # @param [String] subcommand The configuration subcommand (default: 'show')
      # @return [void] Initiates the configuration action
      def handle_config
        subcommand = @args.first || 'show'

        BlueprintsCLI::Actions::Config.new(
          subcommand: subcommand
        ).call
      end

      # Displays help information for the blueprint command
      #
      # @return [void] Outputs help information to the console
      def show_help
        puts <<~HELP
          Blueprint Management Commands:

          📝 Content Management:
            blueprint submit <file_or_code>     Submit a new blueprint
            blueprint edit <id>                 Edit existing blueprint (delete + resubmit)
            blueprint delete [id]               Delete blueprint (interactive if no ID)
            blueprint export <id> [file]        Export blueprint code to file

          📋 Browsing & Search:
            blueprint list                      List all blueprints
            blueprint browse                    Interactive blueprint browser
            blueprint view <id>                 View specific blueprint
            blueprint search <query>            Search blueprints by content

          🤖 Code Generation:
            blueprint generate <description>    Generate code from natural language

          🔧 Configuration:
            blueprint config [show|setup]      Manage configuration

          Options:
            --format FORMAT                     Output format (table, json, summary, detailed)
            --interactive                       Interactive mode with prompts
            --output FILE                       Output file path
            --output_dir DIR                    Output directory for generated files
            --analyze                          Include AI analysis and suggestions
            --force                            Skip confirmation prompts (use with caution)
            --limit N                          Number of blueprints to use as context (default: 5)
            --auto_describe=false              Disable auto-description generation
            --auto_categorize=false            Disable auto-categorization

          Examples:
            blueprint submit my_code.rb
            blueprint submit 'puts "hello world"'
            blueprint list --format summary
            blueprint browse
            blueprint view 123 --analyze
            blueprint edit 123
            blueprint delete 123
            blueprint delete --force 123
            blueprint delete                        # Interactive selection
            blueprint search "ruby class"
            blueprint export 123 my_blueprint.rb
            blueprint generate "Create a Ruby web server using Sinatra"
            blueprint generate "Python data analysis script" --output_dir ./analysis
            blueprint generate "React component for user login" --limit 3 --force

        HELP
      end
    end
  end
end
