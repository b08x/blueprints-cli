# frozen_string_literal: true

require 'tty-file'

module BlueprintsCLI
  module Actions
    ##
    # Generate handles natural language to code generation using existing blueprints
    # as context via vector similarity search. It creates files in an output directory
    # using tty-file for safe file operations.
    #
    # @example Basic usage:
    #   action = Generate.new(
    #     prompt: "Create a Ruby web server using Sinatra",
    #     output_dir: "./generated",
    #     limit: 5
    #   )
    #   action.call
    class Generate < Sublayer::Actions::Base
      ##
      # Initializes a new Generate action with the provided prompt and options.
      #
      # @param prompt [String] The natural language description of code to generate
      # @param output_dir [String] The output directory for generated files (default: "./generated")
      # @param limit [Integer] The number of similar blueprints to use as context (default: 5)
      # @param force [Boolean] Whether to overwrite existing files (default: false)
      # @return [Generate] A new instance of Generate.
      def initialize(prompt:, output_dir: './generated', limit: 5, force: false)
        @prompt = prompt
        @output_dir = File.expand_path(output_dir)
        @limit = limit
        @force = force
        @db = BlueprintsCLI::BlueprintDatabase.new
      end

      ##
      # Executes the code generation process. This includes searching for relevant
      # blueprints, generating code using AI, and creating output files.
      #
      # @return [Hash] Results including success status, generated files, and metadata
      def call
        BlueprintsCLI.logger.step('Starting code generation process...')

        # Search for relevant blueprints using vector similarity
        relevant_blueprints = search_relevant_blueprints

        if relevant_blueprints.empty?
          BlueprintsCLI.logger.warn('No relevant blueprints found for context')
          return { success: false, error: 'No relevant blueprints found' }
        end

        BlueprintsCLI.logger.info("Found #{relevant_blueprints.length} relevant blueprints for context")

        # Generate code using AI with blueprint context
        generation_result = generate_code_with_context(relevant_blueprints)

        return generation_result unless generation_result[:success]

        # Create output files
        file_results = create_output_files(generation_result[:files])

        {
          success: true,
          prompt: @prompt,
          output_dir: @output_dir,
          relevant_blueprints: relevant_blueprints.map { |bp| bp[:id] },
          generated_files: file_results,
          metadata: generation_result[:metadata]
        }
      rescue StandardError => e
        BlueprintsCLI.logger.failure("Error during code generation: #{e.message}")
        { success: false, error: e.message }
      end

      private

      ##
      # Searches for blueprints relevant to the generation prompt using vector similarity
      #
      # @return [Array<Hash>] Array of relevant blueprint records
      def search_relevant_blueprints
        BlueprintsCLI.logger.info('Searching for relevant blueprints...')

        results = @db.search_blueprints(query: @prompt, limit: @limit)

        results.each do |blueprint|
          BlueprintsCLI.logger.debug("Found blueprint: #{blueprint[:name]} (distance: #{blueprint[:distance]})")
        end

        results
      end

      ##
      # Generates code using AI with relevant blueprints as context
      #
      # @param relevant_blueprints [Array<Hash>] The blueprints to use as context
      # @return [Hash] Generation result with files and metadata
      def generate_code_with_context(relevant_blueprints)
        BlueprintsCLI.logger.info('Generating code with AI...')

        context = build_blueprint_context(relevant_blueprints)
        generation_prompt = build_generation_prompt(context)

        begin
          generated_content = generate_with_ai(generation_prompt)
          files = parse_generated_content(generated_content)

          {
            success: true,
            files: files,
            metadata: {
              generation_prompt: generation_prompt,
              context_blueprints: relevant_blueprints.length,
              timestamp: Time.now
            }
          }
        rescue RubyLLM::Error => e
          BlueprintsCLI::Logger.ai_error(e)
          { success: false, error: "AI Generation Failed: #{e.message}" }
        rescue StandardError => e
          BlueprintsCLI.logger.failure("An unexpected error occurred during AI generation: #{e.message}")
          { success: false, error: e.message }
        end
      end

      ##
      # Builds context string from relevant blueprints
      #
      # @param blueprints [Array<Hash>] The relevant blueprints
      # @return [String] Formatted context for AI
      def build_blueprint_context(blueprints)
        context_parts = []

        blueprints.each_with_index do |blueprint, index|
          context_parts << <<~CONTEXT
            ## Blueprint #{index + 1}: #{blueprint[:name] || 'Untitled'}
            **Description:** #{blueprint[:description] || 'No description'}
            **Categories:** #{blueprint[:categories]&.map { |c| c[:title] }&.join(', ') || 'None'}

            **Code:**
            ```
            #{blueprint[:code]}
            ```

          CONTEXT
        end

        context_parts.join("\n")
      end

      ##
      # Builds the generation prompt for AI
      #
      # @param context [String] The blueprint context
      # @return [String] Complete prompt for AI generation
      def build_generation_prompt(context)
        <<~PROMPT
          You are a code generation assistant. Based on the user's request and the provided blueprint examples, generate appropriate code files.

          ## User Request:
          #{@prompt}

          ## Available Blueprint Examples:
          #{context}

          ## Instructions:
          1. Analyze the user's request and the provided blueprint examples
          2. Generate appropriate code that fulfills the user's request
          3. Use patterns and approaches from the relevant blueprints where applicable
          4. Format your response as multiple files if needed
          5. Include proper file headers, comments, and documentation
          6. Suggest appropriate file names and extensions

          ## Response Format:
          Please structure your response as follows:

          FILE: filename.ext
          ```language
          [file content here]
          ```

          FILE: another_file.ext
          ```language
          [another file content here]
          ```

          Provide complete, working code that addresses the user's request.
        PROMPT
      end

      ##
      # Parses generated content to extract individual files
      #
      # @param content [String] The AI-generated content
      # @return [Array<Hash>] Array of file specifications
      def parse_generated_content(content)
        files = []
        current_file = nil
        current_content = []
        in_code_block = false

        content.lines.each do |line|
          line = line.chomp

          if line.start_with?('FILE: ')
            # Save previous file if exists
            if current_file
              files << {
                name: current_file,
                content: current_content.join("\n"),
                language: detect_language(current_file)
              }
            end

            # Start new file
            current_file = line.sub('FILE: ', '').strip
            current_content = []
            in_code_block = false
          elsif line.start_with?('```')
            in_code_block = !in_code_block
          elsif in_code_block && current_file
            current_content << line
          end
        end

        # Save last file
        if current_file
          files << {
            name: current_file,
            content: current_content.join("\n"),
            language: detect_language(current_file)
          }
        end

        # If no files were parsed, treat the entire content as a single file
        if files.empty?
          files << {
            name: guess_filename_from_prompt,
            content: content,
            language: 'text'
          }
        end

        files
      end

      ##
      # Detects programming language from filename
      #
      # @param filename [String] The filename
      # @return [String] The detected language
      def detect_language(filename)
        ext = File.extname(filename).downcase

        case ext
        when '.rb' then 'ruby'
        when '.py' then 'python'
        when '.js' then 'javascript'
        when '.ts' then 'typescript'
        when '.java' then 'java'
        when '.cpp', '.cc', '.cxx' then 'cpp'
        when '.c' then 'c'
        when '.go' then 'go'
        when '.rs' then 'rust'
        when '.php' then 'php'
        when '.sh' then 'bash'
        when '.sql' then 'sql'
        when '.html' then 'html'
        when '.css' then 'css'
        when '.json' then 'json'
        when '.yaml', '.yml' then 'yaml'
        when '.xml' then 'xml'
        when '.md' then 'markdown'
        else 'text'
        end
      end

      ##
      # Guesses a filename from the prompt when no files are parsed
      #
      # @return [String] A default filename
      def guess_filename_from_prompt
        # Simple heuristic to guess file extension from prompt
        prompt_lower = @prompt.downcase

        if prompt_lower.include?('ruby') || prompt_lower.include?('.rb')
          'generated_code.rb'
        elsif prompt_lower.include?('python') || prompt_lower.include?('.py')
          'generated_code.py'
        elsif prompt_lower.include?('javascript') || prompt_lower.include?('.js')
          'generated_code.js'
        elsif prompt_lower.include?('typescript') || prompt_lower.include?('.ts')
          'generated_code.ts'
        elsif prompt_lower.include?('java')
          'GeneratedCode.java'
        elsif prompt_lower.include?('html')
          'generated.html'
        elsif prompt_lower.include?('css')
          'generated.css'
        else
          'generated_code.txt'
        end
      end

      ##
      # Generates content using AI via RubyLLM
      #
      # @param prompt [String] The generation prompt
      # @return [String] The generated content
      def generate_with_ai(prompt)
        require 'ruby_llm'

        BlueprintsCLI.logger.debug("Starting AI generation with prompt length: #{prompt.length}")

        BlueprintsCLI.logger.debug('Creating configuration...')
        config = BlueprintsCLI::Configuration.new
        BlueprintsCLI.logger.debug('Configuration created successfully')

        # Get AI configuration
        BlueprintsCLI.logger.debug('Fetching AI provider...')
        provider = config.fetch(:ai, :provider) || 'gemini'
        BlueprintsCLI.logger.debug("Provider: #{provider}")

        BlueprintsCLI.logger.debug('Fetching AI model...')
        model = config.fetch(:ai, :model) || 'gemini-2.0-flash'
        BlueprintsCLI.logger.debug("Model: #{model}")

        BlueprintsCLI.logger.debug('Fetching API key...')
        api_key = config.ai_api_key(provider)
        BlueprintsCLI.logger.debug("API key present: #{!api_key.nil? && !api_key.empty?}")

        unless api_key
          raise RubyLLM::ConfigurationError, "No API key found for #{provider}. Please configure your AI settings."
        end

        # Create RubyLLM client
        llm_config = {
          provider: provider.to_sym,
          model: model,
          api_key: api_key
        }
        BlueprintsCLI.logger.debug("LLM config prepared: #{llm_config.keys}")

        BlueprintsCLI.logger.debug('Creating RubyLLM chat client...')
        chat = RubyLLM::Chat.new(model: llm_config[:model])
        BlueprintsCLI.logger.debug('RubyLLM chat client created successfully')

        # Generate content
        BlueprintsCLI.logger.debug('Calling completion method...')
        response = chat.with_temperature(0.3).ask(prompt)

        chat.on_end_message do |message|
          BlueprintsCLI.logger.debug('Completion method returned successfully')
          # NOTE: message might be nil if an error occurred during the request
          if message&.output_tokens
            BlueprintsCLI.logger.debug("Used #{message.input_tokens + message.output_tokens} tokens")
          end
        end

        BlueprintsCLI.logger.debug('Extracting content from response...')
        content = response.content
        BlueprintsCLI.logger.debug("Content extracted successfully, length: #{content.length}")

        content
      end

      ##
      # Creates output files using tty-file
      #
      # @param files [Array<Hash>] The files to create
      # @return [Array<Hash>] Results of file creation
      def create_output_files(files)
        BlueprintsCLI.logger.info("Creating #{files.length} output files in #{@output_dir}")

        file_results = []

        files.each do |file_spec|
          file_path = File.join(@output_dir, file_spec[:name])

          begin
            TTY::File.create_file(
              file_path,
              file_spec[:content],
              force: @force,
              verbose: true,
              color: :green
            )

            file_results << {
              name: file_spec[:name],
              path: file_path,
              success: true,
              language: file_spec[:language]
            }

            BlueprintsCLI.logger.success("Created file: #{file_path}")
          rescue StandardError => e
            file_results << {
              name: file_spec[:name],
              path: file_path,
              success: false,
              error: e.message
            }

            BlueprintsCLI.logger.failure("Failed to create file #{file_path}: #{e.message}")
          end
        end

        file_results
      end
    end
  end
end
