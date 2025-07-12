# frozen_string_literal: true

require 'tty-box'

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
        left_box = create_box(left_content, title: left_title, style: left_style, width: 60)
        right_box = create_box(right_content, title: right_title, style: right_style, width: 60)

        "#{left_box}\n#{right_box}"
      end

      private

      # Creates a TTY::Box with standardized styling
      # @param content [String] The content to display
      # @param title [String] The box title
      # @param style [Symbol] The predefined style to use
      # @param options [Hash] Additional TTY::Box options
      # @return [String] The formatted box
      def create_box(content, title:, style:, **options)
        default_options = {
          title: { top_left: title },
          padding: 1
        }

        style_options = STYLES[style] || STYLES[:info]
        box_options = default_options.merge(style_options).merge(options)

        TTY::Box.frame(content, **box_options)
      end
    end
  end
end