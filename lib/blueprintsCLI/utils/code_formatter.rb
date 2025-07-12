# frozen_string_literal: true

require 'rouge'
require 'tty-screen'
require_relative 'language_detector'

module BlueprintsCLI
  module Utils
    # Utility class for formatting code with syntax highlighting
    class CodeFormatter
      class << self
        # Format code with syntax highlighting using Rouge directly
        # @param code [String] The raw code to format
        # @param language [String, nil] Optional language override
        # @return [String] The formatted code with syntax highlighting
        def format(code, language: nil)
          return '' if code.nil? || code.strip.empty?

          # Detect language if not provided
          detected_language = language || LanguageDetector.detect(code)

          # Use Rouge for syntax highlighting
          highlight_with_rouge(code, detected_language)
        end

        # Format code for display in a TTY::Box with syntax highlighting
        # @param code [String] The raw code to format
        # @param language [String, nil] Optional language override
        # @return [String] The formatted code ready for TTY::Box display
        def format_for_box(code, language: nil)
          # Get highlighted code from Rouge
          format(code, language: language)
        end

        private

        # Highlight code using Rouge directly with Terminal256 formatter
        # @param code [String] The code content
        # @param language [String] The programming language
        # @return [String] The highlighted code
        def highlight_with_rouge(code, language)
          # Find the appropriate lexer for the language
          lexer = find_lexer(language)
          
          # Use Rouge's Terminal256 formatter for clean ANSI output
          formatter = Rouge::Formatters::Terminal256.new
          
          # Highlight the code and clean up trailing reset codes
          highlighted = formatter.format(lexer.lex(code.strip))
          clean_trailing_codes(highlighted)
        rescue StandardError => e
          # If highlighting fails, return plain text
          code.strip
        end

        # Clean up trailing reset codes that can appear after highlighting
        # @param highlighted [String] The highlighted code with potential trailing codes
        # @return [String] Cleaned highlighted code
        def clean_trailing_codes(highlighted)
          cleaned = highlighted
            .gsub(/\e\[38;5;230m\e\[39m\s*$/, '')                    # Remove trailing empty color sequences
            .gsub(/\e\[38;5;230m\e\[39m\n/, "\n")                    # Remove empty color sequences before newlines
            .gsub(/(\e\[39m)\e\[38;5;230m\e\[39m/, '\1')              # Remove redundant color resets
            .gsub(/\]\[0m/, ']')                                      # Fix corrupted closing brackets
            .gsub(/\[0m\s*$/, '')                                     # Remove trailing reset codes
            .gsub(/\[0m(?=\s*\n)/, '')                               # Remove reset codes before newlines
            .gsub(/(\w+)\[0m(\s*$)/, '\1\2')                         # Fix words ending with reset codes
            .gsub(/\]\[38;5;\d+[;\d]*m/, ']')                        # Fix corrupted bracket color codes
            .gsub(/(\w)\[38;5;\d+[;\d]*m([^a-zA-Z])/, '\1\2')        # Fix mid-word color codes
            .strip

          # Final cleanup pass to remove any remaining malformed sequences
          cleaned
            .gsub(/\[38;5;\d+[;\d]*m(?![a-zA-Z])/, '')               # Remove orphaned color codes
            .gsub(/\[39[;\d]*m(?![a-zA-Z])/, '')                     # Remove orphaned reset codes
        end

        # Find the appropriate Rouge lexer for the given language
        # @param language [String] The programming language
        # @return [Rouge::Lexer] The lexer instance
        def find_lexer(language)
          # Map our language detection to Rouge lexer names
          rouge_language = map_to_rouge_language(language)
          
          # Find the lexer, fallback to PlainText if not found
          Rouge::Lexer.find(rouge_language) || Rouge::Lexers::PlainText.new
        end

        # Map our language names to Rouge lexer names
        # @param language [String] Our detected language
        # @return [String] Rouge lexer name
        def map_to_rouge_language(language)
          case language.to_s.downcase
          when 'javascript' then 'js'
          when 'typescript' then 'ts'
          when 'cpp' then 'cpp'
          when 'c' then 'c'
          when 'python' then 'python'
          when 'ruby' then 'ruby'
          when 'java' then 'java'
          when 'php' then 'php'
          when 'shell' then 'shell'
          when 'go' then 'go'
          when 'rust' then 'rust'
          when 'sql' then 'sql'
          when 'yaml' then 'yaml'
          when 'json' then 'json'
          when 'html' then 'html'
          when 'css' then 'css'
          when 'xml' then 'xml'
          else 'text'
          end
        end
      end
    end
  end
end