# frozen_string_literal: true

module Processors
  module Text
    # Processes markdown content and splits it into structured sections
    class Markdown < Base
      # Data structures for sections
      Section = Struct.new(:title, :content_lines, :start_line, :end_line, :subsections)
      Subsection = Struct.new(:type, :title, :content, :start_line, :end_line, :parent_title)

      MAX_SLUG_LENGTH = 50

      def process(input)
        if File.exist?(input)
          content = File.read(input, encoding: 'UTF-8')
          filename = File.basename(input)
        else
          content = input
          filename = 'unknown.md'
        end

        split_markdown_content(content, filename)
      rescue StandardError => e
        log_error("Failed to process markdown: #{e.message}")
        []
      end

      private

      def split_markdown_content(content, original_filename)
        lines = content.lines
        sections = extract_level2_sections(lines)

        return [] if sections.empty?

        sections.map.with_index do |section, section_idx|
          subsections = extract_subsections(section, section_idx + 1, original_filename)
          {
            section_info: {
              title: section.title,
              start_line: section.start_line,
              end_line: section.end_line,
              original_file: original_filename
            },
            subsections: subsections
          }
        end
      end

      def extract_level2_sections(lines)
        sections = []
        buffer = []
        current_start_line = 1
        current_title = 'Introduction'

        lines.each_with_index do |line, zero_idx|
          current_line_num = zero_idx + 1

          if (match = line.match(/^## (.*)/))
            add_section_if_buffer_present(sections, current_title, buffer, current_start_line)
            buffer = [line]
            current_title = match[1].strip
            current_start_line = current_line_num
          else
            buffer << line
          end
        end

        add_section_if_buffer_present(sections, current_title, buffer, current_start_line)
        sections
      end

      def add_section_if_buffer_present(sections, title, buffer, start_line)
        return if buffer.empty?

        end_line = start_line + buffer.count - 1
        sections << Section.new(title, buffer.dup, start_line, end_line, [])
        buffer.clear
      end

      def extract_subsections(section, section_idx, original_filename)
        extractor = SubsectionExtractor.new(
          section.content_lines,
          section.start_line,
          section.title,
          section_idx,
          original_filename
        )
        extractor.extract
      end

      # Internal class for extracting subsections
      class SubsectionExtractor
        def initialize(lines, start_line, parent_title, section_idx, original_filename)
          @lines = lines
          @start_line = start_line
          @parent_title = parent_title
          @section_idx = section_idx
          @original_filename = original_filename
          @subsections = []
          @text_buffer = []
          @text_buffer_start = -1
          @current_idx = 0
        end

        def extract
          while @current_idx < @lines.length
            line = @lines[@current_idx]
            consumed = try_special_handlers(line)

            if consumed.positive?
              @current_idx += consumed
            else
              add_to_text_buffer(line)
              @current_idx += 1
            end
          end

          flush_text_buffer(@lines.length - 1)
          @subsections
        end

        private

        def add_to_text_buffer(line)
          @text_buffer_start = @current_idx if @text_buffer.empty?
          @text_buffer << line
        end

        def flush_text_buffer(last_idx)
          return if @text_buffer.empty? || @text_buffer_start == -1

          start_abs = @start_line + @text_buffer_start
          end_abs = @start_line + last_idx

          @subsections << create_subsection_data(
            'text',
            'Text Content',
            @text_buffer.join,
            start_abs,
            end_abs
          )

          @text_buffer.clear
          @text_buffer_start = -1
        end

        def create_subsection_data(type, title, content, start_line, end_line)
          {
            metadata: {
              original_file: @original_filename,
              parent_section_title: @parent_title,
              subsection_type: type,
              title: title,
              start_line: start_line,
              end_line: end_line,
              filename: generate_filename(type, title)
            },
            content: content.strip
          }
        end

        def generate_filename(_type, title)
          section_num = format('%03d', @section_idx)
          subsection_num = format('%03d', @subsections.length + 1)

          parent_slug = slugify(@parent_title, 'section')
          title_slug = slugify(title, 'content')

          combined_slug = truncate_slug("#{parent_slug}-#{title_slug}")
          "#{section_num}-#{subsection_num}-#{combined_slug}.md"
        end

        def slugify(text, fallback = 'content')
          slug = text.to_s.downcase
                     .gsub(/\s+/, '-')
                     .gsub(/[^\w.:()-]/, '')
                     .gsub(/^-+|-+$/, '')
          slug.empty? ? fallback : slug
        end

        def truncate_slug(slug)
          if slug.length > MAX_SLUG_LENGTH
            slug[0...MAX_SLUG_LENGTH].gsub(/-+$/, '')
          else
            slug
          end
        end

        def try_special_handlers(line)
          handlers = [
            method(:handle_code_block),
            method(:handle_blockquote),
            method(:handle_table),
            method(:handle_image),
            method(:handle_link)
          ]

          handlers.each do |handler|
            consumed = handler.call(line)
            next unless consumed.positive?

            if @current_idx > @text_buffer_start && @text_buffer_start != -1
              flush_text_buffer(@current_idx - 1)
            end
            return consumed
          end

          0
        end

        def handle_code_block(line)
          match = line.match(/^```(\w*)$/) || line.match(/^~~~(\w*)$/)
          return 0 unless match

          fence = match[0][0, 3]
          lang = match[1]
          lines = [line]
          idx = @current_idx + 1

          while idx < @lines.length
            lines << @lines[idx]
            break if @lines[idx].strip == fence

            idx += 1
          end

          title = lang.empty? ? 'Code Block' : "Code Block (#{lang})"
          start_abs = @start_line + @current_idx
          end_abs = @start_line + (idx < @lines.length ? idx : @lines.length - 1)

          @subsections << create_subsection_data(
            'codeblock',
            title,
            lines.join,
            start_abs,
            end_abs
          )

          lines.length
        end

        def handle_blockquote(line)
          return 0 unless line.strip.start_with?('>')

          lines = []
          idx = @current_idx

          while idx < @lines.length && @lines[idx].strip.start_with?('>')
            lines << @lines[idx]
            idx += 1
          end

          return 0 if lines.empty?

          start_abs = @start_line + @current_idx
          end_abs = @start_line + idx - 1

          @subsections << create_subsection_data(
            'blockquote',
            'Blockquote',
            lines.join,
            start_abs,
            end_abs
          )

          lines.length
        end

        def handle_table(line)
          return 0 unless line.strip.start_with?('|') && line.count('|') >= 2

          lines = []
          idx = @current_idx

          while idx < @lines.length &&
                @lines[idx].strip.start_with?('|') &&
                @lines[idx].count('|') >= 2

            lines << @lines[idx]
            idx += 1
          end

          return 0 if lines.empty?

          start_abs = @start_line + @current_idx
          end_abs = @start_line + idx - 1

          @subsections << create_subsection_data(
            'table',
            'Table',
            lines.join,
            start_abs,
            end_abs
          )

          lines.length
        end

        def handle_image(line)
          match = line.strip.match(/^!\[([^\]]*)\]\(([^\)]+)\)$/)
          return 0 unless match

          title = match[1].empty? ? 'Image' : "Image: #{match[1]}"
          start_abs = @start_line + @current_idx

          @subsections << create_subsection_data(
            'image',
            title,
            line,
            start_abs,
            start_abs
          )

          1
        end

        def handle_link(line)
          match = line.strip.match(/^\[([^\]]+)\]\(([^\)]+)\)$/)
          return 0 unless match

          title = match[1].empty? ? 'Link' : "Link: #{match[1]}"
          start_abs = @start_line + @current_idx

          @subsections << create_subsection_data(
            'link',
            title,
            line,
            start_abs,
            start_abs
          )

          1
        end
      end
    end
  end
end
