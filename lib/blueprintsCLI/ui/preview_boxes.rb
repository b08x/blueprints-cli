# frozen_string_literal: true

require 'tty-box'
require 'tty-screen'
require_relative '../utils/code_formatter'

module BlueprintsCLI
  module UI
    # Module for standardized preview box styling and creation
    module PreviewBoxes
      # Standard preview box styles
      STYLES = {
        info: { style: { border: { fg: :blue } } },
        code: { style: { border: { fg: :green } } },
        warning: { style: { border: { fg: :yellow } } },
        error: { style: { border: { fg: :red } } },
        diff: { style: { border: { fg: :cyan } } },
        success: { style: { border: { fg: :green } } },
        metadata: { style: { border: { fg: :blue } } },
        description: { style: { border: { fg: :cyan } } },
        suggestions: { style: { border: { fg: :magenta } } }
      }.freeze

      module_function

      # Creates a standardized info box
      # @param content [String] The content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def info_box(content, title: 'Information', **options)
        create_box(content, title: title, style: :info, **options)
      end

      # Creates a standardized code preview box
      # @param content [String] The code content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def code_box(content, title: 'Code', **options)
        create_box(content, title: title, style: :code, **options)
      end

      # Creates a syntax-highlighted code preview box
      # @param content [String] The code content to display
      # @param title [String] The box title
      # @param language [String, nil] Optional language override for syntax highlighting
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box with syntax highlighting
      def highlighted_code_box(content, title: 'Code', language: nil, **options)
        # Calculate optimal width based on terminal dimensions
        terminal_width = TTY::Screen.width
        content_width = calculate_content_width(content, terminal_width)
        
        highlighted_content = Utils::CodeFormatter.format_for_box(content, language: language)
        
        # Set width option if not provided and content fits nicely
        box_options = options.dup
        if !options.key?(:width) && content_width < terminal_width
          box_options[:width] = 
            content_width
        end
        
        create_box(highlighted_content, title: title, style: :code, **box_options)
      end

      # Creates a standardized warning box
      # @param content [String] The warning content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def warning_box(content, title: 'Warning', **options)
        create_box(content, title: title, style: :warning, **options)
      end

      # Creates a standardized error box
      # @param content [String] The error content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def error_box(content, title: 'Error', **options)
        create_box(content, title: title, style: :error, **options)
      end

      # Creates a standardized diff/comparison box
      # @param content [String] The diff content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def diff_box(content, title: 'Comparison', **options)
        create_box(content, title: title, style: :diff, **options)
      end

      # Creates a standardized success box
      # @param content [String] The success content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def success_box(content, title: 'Success', **options)
        create_box(content, title: title, style: :success, **options)
      end

      # Creates a metadata preview box
      # @param content [String] The metadata content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def metadata_box(content, title: 'Metadata', **options)
        create_box(content, title: title, style: :metadata, **options)
      end

      # Creates a description preview box
      # @param content [String] The description content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def description_box(content, title: 'Description', **options)
        create_box(content, title: title, style: :description, **options)
      end

      # Creates an AI suggestions preview box
      # @param content [String] The suggestions content to display
      # @param title [String] The box title
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def suggestions_box(content, title: 'AI Suggestions', **options)
        create_box(content, title: title, style: :suggestions, **options)
      end

      # Creates a side-by-side comparison of two contents
      # @param left_content [String] Content for the left box
      # @param right_content [String] Content for the right box
      # @param left_title [String] Title for the left box
      # @param right_title [String] Title for the right box
      # @param left_style [Symbol] Style for the left box
      # @param right_style [Symbol] Style for the right box
      # @return [String] The formatted side-by-side boxes
      def side_by_side(left_content, right_content,
                       left_title: 'Before', right_title: 'After',
                       left_style: :error, right_style: :success)
        # Calculate width for side-by-side display
        terminal_width = TTY::Screen.width
        box_width = [(terminal_width / 2) - 4, 40].max  # Minimum 40 chars per box
        
        left_box = create_box(left_content, title: left_title, style: left_style, width: box_width)
        right_box = create_box(right_content, title: right_title, style: right_style, 
                                              width: box_width)

        "#{left_box}\n#{right_box}"
      end

      private_class_method

      # Creates a TTY::Box with standardized styling
      # @param content [String] The content to display
      # @param title [String] The box title
      # @param style [Symbol] The predefined style to use
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def self.create_box(content, title:, style:, **options)
        default_options = {
          title: { top_left: title },
          padding: 1
        }

        style_options = STYLES[style] || STYLES[:info]
        box_options = default_options.merge(style_options).merge(options)

        TTY::Box.frame(content, **box_options)
      end

      # Calculate optimal content width based on code and terminal dimensions
      # @param content [String] The content to analyze
      # @param terminal_width [Integer] The terminal width
      # @return [Integer] The optimal content width
      def self.calculate_content_width(content, terminal_width)
        return terminal_width - 4 if content.nil? || content.empty?
        
        begin
          # Get the longest line in the content (excluding ANSI codes)
          max_line_length = content.lines.map { |line| strip_ansi_codes(line).length }.max || 0
          
          # Add padding for box borders and margins (roughly 6 characters)
          content_width = max_line_length + 6
          
          # Ensure we don't exceed terminal width, but use at least 50% of terminal
          min_width = [terminal_width * 0.5, 60].max.to_i
          max_width = terminal_width - 4  # Leave some margin
          
          [[content_width, min_width].max, max_width].min
        rescue StandardError
          # Fallback to a reasonable default width
          terminal_width - 4
        end
      end

      # Strip ANSI escape codes from text for length calculation
      # @param text [String] The text with potential ANSI codes
      # @return [String] Plain text without ANSI codes
      def self.strip_ansi_codes(text)
        return '' if text.nil?
        
        text.to_s.gsub(/\e\[[0-9;]*m/, '').gsub(/\[[0-9;]*m/, '')
      rescue StandardError
        text.to_s
      end
    end
  end
end