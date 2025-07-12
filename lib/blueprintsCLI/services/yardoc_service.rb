# frozen_string_literal: true

require 'ruby_llm'
require 'tty-box'
require 'tty-prompt'
require 'tty-spinner'

module BlueprintsCLI
  module Services
    # Service to generate YARD documentation for a Ruby file using an LLM.
    class YardocService
      # The prompt template for generating YARD documentation.
      PROMPT_TEMPLATE = <<~'PROMPT'
        # SFL-Framework YARD Documentation Generation System Prompt

        ## Context

        **Register Variables:**

        - **Field**: Transforming Ruby code into clear, actionable developer documentation
        - **Tenor**: Developer-to-developer communication with practical, helpful guidance
        - **Mode**: YARD comment format optimized for API comprehension and usage

        **Communicative Purpose**: Produce clear, comprehensive YARD documentation that makes Ruby code immediately understandable and usable by other developers through precise explanation of behavior, parameters, and context.

        Here is the Ruby code to document:

        <ruby_code>
        {{RUBY_CODE}}
        </ruby_code>

        ## Field (Content/Subject Matter)

        **Experiential Function**: Transform Ruby code into practical developer guidance through:

        **Grounding in Usage Context:**

        - Begin with clear method/class purpose that answers "why would I use this?"
        - Connect abstract code behavior to concrete use cases and developer workflows
        - Ground technical implementation in practical problem-solving scenarios

        **Integrating Code Behavior:**

        - Reference specific parameter relationships and their effects on method behavior
        - Include realistic usage examples that demonstrate practical application
        - Document edge cases, error conditions, and important behavioral nuances
        - Connect method behavior to broader class or module functionality

        **Documentation Completeness:**

        - Link individual methods to overall class/module purpose and design patterns
        - Connect parameter choices to common Ruby idioms and conventions
        - Bridge specific implementation details to general Ruby best practices

        ## Tenor (Relationship/Voice)

        **Interpersonal Function**: Establish helpful developer support through:

        **Practical Developer Roles:**

        - **API Explainer**: Clear description of what the method does and how to use it
        - **Usage Guide**: Concrete examples that show proper implementation
        - **Warning System**: Proactive alerts about potential issues or edge cases
        - **Future Helper**: Context that aids debugging and maintenance

        **Balanced Communication:**

        - **Clarity Focus (80%)**: Straightforward explanation of behavior, parameters, and returns
        - **Contextual Insight (20%)**: Strategic notes about usage patterns, gotchas, and best practices

        **Developer-Centric Power Dynamics:**

        - Respect reader's Ruby knowledge while providing essential implementation details
        - Offer clear guidance without over-explaining basic Ruby concepts
        - Use inclusive language that assumes collaborative code maintenance

        ## Mode (Organization/Texture)

        **Textual Function**: Structure precise, YARD-compliant documentation through:

        **YARD Format Adherence:**

        - **Method Description**: Concise opening that clearly states purpose and behavior
        - **Parameter Documentation**: `@param [Type] name description` with specific type information
        - **Return Documentation**: `@return [Type] description` explaining what the method produces
        - **Example Usage**: `@example` blocks showing realistic implementation scenarios

        **Information Hierarchy:**

        - Lead with method purpose and high-level behavior
        - Follow with parameter details in logical order
        - Include return value description with type information
        - Conclude with examples and special considerations

        **Documentation Patterns:**

        - Use active voice for method descriptions: "Validates user input" not "User input is validated"
        - Employ specific type annotations: `[String, nil]` not just `[Object]`
        - Include realistic parameter examples in descriptions
        - Maintain consistent terminology throughout related methods

        ## Implementation Guidelines

        **YARD Comment Structure:**

        ```ruby
        ##
        # Brief method description explaining primary purpose
        #
        # Optional longer description providing context, usage notes,
        # or important behavioral details
        #
        # @param [Type] param_name Description of parameter and its role
        # @param [Type, nil] optional_param Description with default behavior
        # @return [Type] Description of return value and its structure
        # @raise [ExceptionClass] When and why this exception occurs
        # @example Basic usage
        #   method_call(param1, param2)
        #   # => expected_result
        # @example Advanced usage
        #   method_call(complex_param) do |block_param|
        #     # block implementation
        #   end
        # @since 1.2.0
        # @see RelatedClass#related_method
        def method_name(params)
        ```

        **Documentation Process:**

        1. **Analyze Method Purpose**: What problem does this method solve?
        2. **Identify Parameter Relationships**: How do parameters interact to produce the result?
        3. **Document Return Behavior**: What does the method produce and under what conditions?
        4. **Consider Edge Cases**: What exceptional conditions or error states exist?
        5. **Provide Usage Examples**: What realistic scenarios demonstrate proper usage?

        **Type Documentation Standards:**

        - Use specific Ruby types: `String`, `Integer`, `Hash`, `Array`
        - Document hash structures: `Hash{String => Object}` or `Hash{Symbol => String}`
        - Include nil possibilities: `String, nil` for optional returns
        - Use duck typing when appropriate: `#to_s` for objects that respond to `to_s`

        **Example Quality Requirements:**

        - Show realistic parameter values, not `foo` and `bar`
        - Demonstrate actual method calls with expected outputs
        - Include block usage when relevant
        - Show both simple and complex usage scenarios

        **Output Requirements:**

        - Complete YARD comment block ready for insertion above the method
        - Accurate type annotations based on code analysis
        - Clear, actionable descriptions that help developers use the method correctly
        - Realistic examples that demonstrate practical usage patterns
        - Proper YARD tag usage following established conventions

        **Anti-Patterns to Avoid:**

        - Vague descriptions that don't explain actual behavior
        - Missing or incorrect type annotations
        - Examples that don't work or use unrealistic data
        - Over-documentation of obvious Ruby concepts
        - Inconsistent terminology across related methods
        - Missing documentation of important edge cases or exceptions

        Generate YARD documentation for the provided ruby code.
        Your output should be the complete, original Ruby code with the new YARD comment blocks inserted directly above the corresponding class and method definitions.
        Do not return only the comments.
      PROMPT

      # Initializes the YardocService.
      # @param file_path [String] The path to the Ruby file to document.
      # @param preview [Boolean] Whether to show preview before writing (default: true)
      def initialize(file_path, preview: true)
        @file_path = file_path
        @preview = preview
        @prompt = TTY::Prompt.new if preview
        
        # Configure RubyLLM with available API keys
        configure_rubyllm
        
        # Initialize chat with appropriate model and provider
        @chat = create_chat_instance
      end

      # Generates YARD documentation for the file.
      # @return [Boolean] true if successful, false otherwise.
      def call
        puts "Generating YARD documentation for #{@file_path}..."
        
        unless File.exist?(@file_path)
          puts "Error: File not found at #{@file_path}"
          return false
        end

        file_content = File.read(@file_path)
        
        # Show before preview if enabled
        if @preview
          show_before_preview(file_content)
        end

        llm_prompt = PROMPT_TEMPLATE.gsub('{{RUBY_CODE}}', file_content)

        begin
          # Set up spinner for AI generation feedback
          spinner = TTY::Spinner.new("[:spinner] Generating YARD documentation with AI...", 
                                     format: :dots)
          
          # Set up callback for streaming response feedback
          @chat.on_new_message do
            spinner.spin
          end
          
          spinner.auto_spin
          response_message = @chat.ask(llm_prompt)
          spinner.success('Documentation generated!')
          
          if response_message && response_message.content && !response_message.content.strip.empty?
            documented_content = response_message.content
            
            # Show after preview and confirm if preview enabled
            if @preview
              return false unless show_after_preview_and_confirm(file_content, documented_content)
            end
            
            File.write(@file_path, documented_content)
            show_success_message
            true
          else
            spinner.error('Empty response from AI') if defined?(spinner)
            puts "Error: Received empty response from LLM."
            false
          end
        rescue => e
          spinner.error('Generation failed') if defined?(spinner)
          puts "Error generating documentation: #{e.message}"
          false
        end
      end

      private

      # Shows a preview of the original code before documentation generation
      def show_before_preview(file_content)
        preview_content = file_content.lines.first(15).join
        preview_content += "\n..." if file_content.lines.length > 15

        before_box = TTY::Box.frame(
          preview_content,
          title: { top_left: '📜 Original Code' },
          style: { border: { fg: :blue } },
          padding: 1
        )
        
        puts before_box
        @prompt.keypress('Press any key to start YARD generation...')
        print TTY::Cursor.clear_screen_down if defined?(TTY::Cursor)
      end

      # Shows before/after preview and asks for confirmation
      def show_after_preview_and_confirm(original_content, documented_content)
        # Show original preview
        original_preview = original_content.lines.first(10).join
        original_preview += "\n..." if original_content.lines.length > 10

        original_box = TTY::Box.frame(
          original_preview,
          title: { top_left: '📜 Before (Original)' },
          style: { border: { fg: :blue } },
          width: 80,
          padding: 1
        )

        # Show documented preview
        documented_preview = documented_content.lines.first(15).join
        documented_preview += "\n..." if documented_content.lines.length > 15

        documented_box = TTY::Box.frame(
          documented_preview,
          title: { top_left: '📚 After (With YARD Documentation)' },
          style: { border: { fg: :green } },
          width: 80,
          padding: 1
        )

        # Display both boxes
        puts original_box
        puts documented_box

        # Ask for confirmation
        @prompt.yes?('Apply YARD documentation to file?')
      end

      # Configure RubyLLM with available API keys
      def configure_rubyllm
        RubyLLM.configure do |config|
          # Use Gemini if available
          if ENV['GEMINI_API_KEY']
            config.gemini_api_key = ENV['GEMINI_API_KEY']
          # Use OpenRouter if available
          elsif ENV['OPENROUTER_API_KEY']
            config.openai_api_key = ENV['OPENROUTER_API_KEY']
            config.openai_api_base = 'https://openrouter.ai/api/v1'
          # Use OpenAI if available
          elsif ENV['OPENAI_API_KEY']
            config.openai_api_key = ENV['OPENAI_API_KEY']
          end
        end
      end

      # Create chat instance with appropriate model and provider
      def create_chat_instance
        if ENV['GEMINI_API_KEY']
          RubyLLM.chat(model: 'gemini-2.0-flash', provider: :gemini)
        elsif ENV['OPENROUTER_API_KEY']
          RubyLLM.chat(model: 'gemini-2.0-flash', provider: :openai)
        elsif ENV['OPENAI_API_KEY']
          RubyLLM.chat(model: 'gpt-4o-mini', provider: :openai)
        else
          raise 'No AI provider configured. Please set GEMINI_API_KEY, OPENROUTER_API_KEY, or OPENAI_API_KEY environment variable.'
        end
      end

      # Shows success message with styled box
      def show_success_message
        success_box = TTY::Box.frame(
          "Successfully generated YARD documentation for:\n#{@file_path}",
          title: { top_left: '✅ Documentation Generated' },
          style: { border: { fg: :green } },
          padding: 1,
          align: :center
        )
        puts success_box
      end
    end
  end
end
