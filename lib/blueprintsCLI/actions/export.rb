# frozen_string_literal: true

module BlueprintsCLI
  module Actions
    ##
    # Export handles the export of blueprints from the database to files.
    #
    # This action allows developers to export blueprints with or without metadata,
    # automatically generating appropriate file paths and handling file conflicts.
    #
    # Example:
    #   action = BlueprintsCLI::Actions::Export.new(id: 123, include_metadata: true)
    #   action.call
    class Export < Sublayer::Actions::Base
      ##
      # Initializes a new Export.
      #
      # @param id [Integer] The ID of the blueprint to export
      # @param output_path [String, nil] The path where the blueprint should be exported.
      #   If nil, a path will be automatically generated.
      # @param include_metadata [Boolean] Whether to include blueprint metadata in the exported file
      # @return [Export] a new instance of Export
      #
      # @example Exporting a blueprint with metadata
      #   action = BlueprintsCLI::Actions::Export.new(
      #     id: 123,
      #     include_metadata: true
      #   )
      def initialize(id:, output_path: nil, include_metadata: false)
        @id = id
        @output_path = output_path
        @include_metadata = include_metadata
        @db = BlueprintsCLI::Wrappers::BlueprintDatabase.new
      end

      ##
      # Executes the blueprint export process.
      #
      # This method retrieves the blueprint from the database, generates an output path
      # if one wasn't provided, checks for file conflicts, and exports the blueprint
      # to the specified file.
      #
      # @return [Boolean] true if the export was successful, false otherwise
      #
      # @example Basic export
      #   action = BlueprintsCLI::Actions::Export.new(id: 123)
      #   action.call #=> true
      def call
        puts "📤 Exporting blueprint #{@id}...".colorize(:blue)

        blueprint = @db.get_blueprint(@id)
        unless blueprint
          puts "❌ Blueprint #{@id} not found".colorize(:red)
          return false
        end

        # Generate output path if not provided
        @output_path ||= generate_output_path(blueprint)

        # Check if file already exists
        if File.exist?(@output_path) && !confirm_overwrite
          puts '❌ Export cancelled'.colorize(:yellow)
          return false
        end

        # Export the blueprint
        export_success = export_blueprint(blueprint)

        if export_success
          puts "✅ Blueprint exported to: #{@output_path}".colorize(:green)
          show_export_summary(blueprint)
          true
        else
          puts '❌ Failed to export blueprint'.colorize(:red)
          false
        end
      rescue StandardError => e
        puts "❌ Error exporting blueprint: #{e.message}".colorize(:red)
        puts e.backtrace.first(3).join("\n") if ENV['DEBUG']
        false
      end

      private

      ##
      # Generates a safe output path for the blueprint file.
      #
      # Creates a filename based on the blueprint name and ID, with an appropriate
      # extension based on the code content. If the file already exists, appends
      # a number to make it unique.
      #
      # @param blueprint [Hash] The blueprint data
      # @return [String] A unique, safe file path for the blueprint
      #
      # @example Generating a path
      #   generate_output_path(blueprint: {name: "My Blueprint", id: 123, code: "def hello\nend"})
      #   #=> "my_blueprint_123.rb"
      def generate_output_path(blueprint)
        # Create safe filename from blueprint name
        safe_name = (blueprint[:name] || 'blueprint').gsub(/[^a-zA-Z0-9_-]/, '_').downcase
        extension = detect_file_extension(blueprint[:code])

        base_filename = "#{safe_name}_#{@id}#{extension}"

        # Check if file exists and add number suffix if needed
        counter = 1
        output_path = base_filename

        while File.exist?(output_path)
          name_part = File.basename(base_filename, extension)
          output_path = "#{name_part}_#{counter}#{extension}"
          counter += 1
        end

        output_path
      end

      ##
      # Detects the appropriate file extension based on the code content.
      #
      # Uses pattern matching to determine the programming language of the code
      # and returns the appropriate file extension.
      #
      # @param code [String] The blueprint code content
      # @return [String] The appropriate file extension
      #
      # @example Detecting Ruby code
      #   detect_file_extension("def hello\nend") #=> ".rb"
      #
      # @example Detecting JavaScript code
      #   detect_file_extension("function hello() {\n}") #=> ".js"
      def detect_file_extension(code)
        case code
        when /class\s+\w+.*<.*ApplicationRecord/m, /def\s+\w+.*end/m, /require ['"].*['"]/m
          '.rb'
        when /function\s+\w+\s*\(/m, /const\s+\w+\s*=/m, /import\s+.*from/m
          '.js'
        when /def\s+\w+\s*\(/m, /import\s+\w+/m, /from\s+\w+\s+import/m
          '.py'
        when /#include\s*<.*>/m, /int\s+main\s*\(/m
          '.c'
        when /public\s+class\s+\w+/m, /import\s+java\./m
          '.java'
        when /fn\s+\w+\s*\(/m, /use\s+std::/m
          '.rs'
        when /func\s+\w+\s*\(/m, /package\s+main/m
          '.go'
        when /<\?php/m, /namespace\s+\w+/m
          '.php'
        when /<!DOCTYPE html/mi, /<html/mi
          '.html'
        when /^#!/m
          '' # Script files often have no extension
        else
          '.txt'
        end
      end

      ##
      # Prompts the user to confirm overwriting an existing file.
      #
      # @return [Boolean] true if the user confirms overwriting, false otherwise
      #
      # @example Confirming overwrite
      #   confirm_overwrite #=> Prompts user and returns true if they respond "y" or "yes"
      def confirm_overwrite
        print "⚠️  File '#{@output_path}' already exists. Overwrite? (y/N): "
        response = STDIN.gets.chomp.downcase
        %w[y yes].include?(response)
      end

      ##
      # Exports the blueprint content to a file.
      #
      # Creates the necessary directories and writes the blueprint content to the file.
      #
      # @param blueprint [Hash] The blueprint data
      # @return [Boolean] true if the export was successful, false otherwise
      #
      # @example Exporting a blueprint
      #   export_blueprint(blueprint: {id: 123, code: "def hello\nend"}) #=> true
      def export_blueprint(blueprint)
        content = build_export_content(blueprint)

        begin
          # Ensure directory exists
          dir = File.dirname(@output_path)
          FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

          # Write the file
          File.write(@output_path, content)
          true
        rescue StandardError => e
          puts "❌ Failed to write file: #{e.message}".colorize(:red)
          false
        end
      end

      ##
      # Builds the content to be exported based on the include_metadata flag.
      #
      # @param blueprint [Hash] The blueprint data
      # @return [String] The content to be exported
      #
      # @example Building content with metadata
      #   build_export_content(blueprint: {id: 123, code: "def hello\nend"}) #=> String with metadata
      def build_export_content(blueprint)
        if @include_metadata
          build_content_with_metadata(blueprint)
        else
          blueprint[:code]
        end
      end

      ##
      # Builds the content with metadata as comments.
      #
      # Adds blueprint metadata as comments at the top of the file, using the
      # appropriate comment style for the file type.
      #
      # @param blueprint [Hash] The blueprint data
      # @return [String] The content with metadata
      #
      # @example Building content with metadata
      #   build_content_with_metadata(blueprint: {id: 123, code: "def hello\nend"})
      #   #=> String with metadata comments followed by code
      def build_content_with_metadata(blueprint)
        content = []

        # Add metadata as comments based on file type
        comment_style = get_comment_style(@output_path)

        content << format_comment('Blueprint Export', comment_style)
        content << format_comment('=' * 50, comment_style)
        content << format_comment("ID: #{blueprint[:id]}", comment_style)
        content << format_comment("Name: #{blueprint[:name]}", comment_style)
        content << format_comment("Description: #{blueprint[:description]}", comment_style)

        if blueprint[:categories] && blueprint[:categories].any?
          category_names = blueprint[:categories].map { |cat| cat[:title] }
          content << format_comment("Categories: #{category_names.join(', ')}", comment_style)
        end

        content << format_comment("Exported: #{Time.now}", comment_style)
        content << format_comment('=' * 50, comment_style)
        content << ''
        content << blueprint[:code]

        content.join("\n")
      end

      ##
      # Determines the comment style based on the file extension.
      #
      # @param filename [String] The filename
      # @return [String] The appropriate comment style
      #
      # @example Getting comment style for Ruby file
      #   get_comment_style("example.rb") #=> "#"
      #
      # @example Getting comment style for JavaScript file
      #   get_comment_style("example.js") #=> "//"
      def get_comment_style(filename)
        case File.extname(filename).downcase
        when '.rb', '.py', '.sh'
          '#'
        when '.js', '.java', '.c', '.cpp', '.cs', '.go', '.rs', '.php'
          '//'
        when '.html', '.xml'
          '<!--'
        when '.css'
          '/*'
        else
          '#'
        end
      end

      ##
      # Formats a comment based on the comment style.
      #
      # @param text [String] The comment text
      # @param style [String] The comment style
      # @return [String] The formatted comment
      #
      # @example Formatting a Ruby comment
      #   format_comment("Hello", "#") #=> "# Hello"
      #
      # @example Formatting an HTML comment
      #   format_comment("Hello", "<!--") #=> "<!-- Hello -->"
      def format_comment(text, style)
        case style
        when '<!--'
          "<!-- #{text} -->"
        when '/*'
          "/* #{text} */"
        else
          "#{style} #{text}"
        end
      end

      ##
      # Displays a summary of the export.
      #
      # @param blueprint [Hash] The blueprint data
      # @return [void]
      #
      # @example Showing export summary
      #   show_export_summary(blueprint: {id: 123, name: "Example"})
      #   #=> Outputs a summary to the console
      def show_export_summary(blueprint)
        puts "\n📋 Export Summary:".colorize(:blue)
        puts "   Blueprint: #{blueprint[:name]} (ID: #{@id})"
        puts "   File: #{@output_path}"
        puts "   Size: #{File.size(@output_path)} bytes"
        puts "   Format: #{@include_metadata ? 'Code with metadata' : 'Code only'}"

        if blueprint[:categories] && blueprint[:categories].any?
          category_names = blueprint[:categories].map { |cat| cat[:title] }
          puts "   Categories: #{category_names.join(', ')}"
        end

        puts ''
        puts '💡 Tip: Use --include-metadata flag to export with blueprint information'.colorize(:cyan)
        puts ''
      end
    end
  end
end
