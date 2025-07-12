# frozen_string_literal: true

require 'ruby_llm'

module BlueprintsCLI
  module Setup
    # ModelConfigurator handles AI model discovery, selection, and configuration.
    # It uses RubyLLM's model registry to discover available models from configured
    # providers and helps users select appropriate models for different tasks.
    class ModelConfigurator
      # Model categories and their purposes
      MODEL_CATEGORIES = {
        chat: {
          name: 'Chat Models',
          description: 'For conversational AI, code generation, and general tasks',
          required: true
        },
        embedding: {
          name: 'Embedding Models',
          description: 'For vector search and semantic similarity',
          required: true
        },
        image: {
          name: 'Image Generation Models',
          description: 'For creating images from text descriptions',
          required: false
        }
      }.freeze

      # Initialize the model configurator
      #
      # @param prompt [TTY::Prompt] TTY prompt instance
      # @param setup_data [Hash] Setup data storage
      def initialize(prompt, setup_data)
        @prompt = prompt
        @setup_data = setup_data
        @logger = BlueprintsCLI.logger
        @available_models = {}
        @selected_models = {}
      end

      # Discover and configure AI models
      #
      # @return [Boolean] True if model configuration completed successfully
      def discover_and_configure
        return false unless providers_configured?

        @logger.info('Discovering available AI models...')

        configure_rubyllm_from_setup
        discover_models
        display_model_summary
        configure_model_preferences
        finalize_model_configuration

        true
      end

      private

      # Check if AI providers are configured
      #
      # @return [Boolean] True if providers are available
      def providers_configured?
        if @setup_data[:providers]&.any?
          true
        else
          @logger.failure('No AI providers configured. Please run provider setup first.')
          false
        end
      end

      # Configure RubyLLM with setup data
      def configure_rubyllm_from_setup
        @logger.info('Configuring RubyLLM with detected providers...')

        RubyLLM.configure do |config|
          @setup_data[:providers].each do |provider_key, provider_config|
            case provider_key
            when :openai
              config.openai_api_key = provider_config[:api_key]
            when :openrouter
              config.openai_api_key = provider_config[:api_key]
              config.openai_api_base = 'https://openrouter.ai/api/v1'
            when :anthropic
              config.anthropic_api_key = provider_config[:api_key]
            when :gemini
              config.gemini_api_key = provider_config[:api_key]
            when :deepseek
              config.deepseek_api_key = provider_config[:api_key]
            end
          end
        end
      end

      # Discover available models from configured providers
      def discover_models
        @logger.info('Refreshing model registry...')
        RubyLLM.models.refresh!

        # Categorize available models
        @available_models[:chat] = filter_chat_models
        @available_models[:embedding] = filter_embedding_models
        @available_models[:image] = filter_image_models

        @logger.success('Model discovery completed!')
      rescue StandardError => e
        @logger.failure("Model discovery failed: #{e.message}")
        @logger.debug(e.backtrace.join("\n")) if ENV['DEBUG']
        fallback_to_default_models
      end

      # Filter chat models from available providers
      #
      # @return [Array<Hash>] Available chat models with metadata
      def filter_chat_models
        provider_keys = @setup_data[:providers].keys

        models = RubyLLM.models.chat_models.select do |model|
          provider_symbol = model.provider.to_sym
          # Map openrouter to openai for filtering
          provider_symbol = :openrouter if provider_symbol == :openai &&
                                           @setup_data[:providers].key?(:openrouter) &&
                                           !@setup_data[:providers].key?(:openai)

          provider_keys.include?(provider_symbol)
        end

        models.map do |model|
          {
            id: model.id,
            name: model.name,
            provider: model.provider,
            context_window: model.context_window,
            supports_vision: model.supports_vision?,
            supports_tools: model.supports_functions?,
            input_price: model.input_price_per_million,
            output_price: model.output_price_per_million,
            family: model.family
          }
        end
      end

      # Filter embedding models from available providers
      #
      # @return [Array<Hash>] Available embedding models with metadata
      def filter_embedding_models
        provider_keys = @setup_data[:providers].keys

        models = RubyLLM.models.embedding_models.select do |model|
          provider_symbol = model.provider.to_sym
          provider_keys.include?(provider_symbol)
        end

        models.map do |model|
          {
            id: model.id,
            name: model.name,
            provider: model.provider,
            dimensions: model.respond_to?(:dimensions) ? model.dimensions : 'Unknown',
            input_price: model.input_price_per_million
          }
        end
      end

      # Filter image generation models from available providers
      #
      # @return [Array<Hash>] Available image models with metadata
      def filter_image_models
        provider_keys = @setup_data[:providers].keys

        # NOTE: RubyLLM may not have a specific image_models filter
        # This is a placeholder implementation
        all_models = begin
          RubyLLM.models.all.select do |model|
            model.respond_to?(:type) &&
              model.type == 'image' &&
              provider_keys.include?(model.provider.to_sym)
          end
        rescue StandardError
          []
        end

        all_models.map do |model|
          {
            id: model.id,
            name: model.name,
            provider: model.provider,
            max_resolution: model.respond_to?(:max_resolution) ? model.max_resolution : 'Unknown'
          }
        end
      end

      # Display summary of discovered models
      def display_model_summary
        puts "\n📊 Model Discovery Summary:"

        MODEL_CATEGORIES.each do |category, info|
          models = @available_models[category] || []
          status = models.any? ? '✓' : '✗'
          count = models.size

          puts "  #{status} #{info[:name]}: #{count} models available"

          if models.any? && count <= 5
            models.each do |model|
              provider_name = get_provider_display_name(model[:provider])
              puts "    - #{model[:name]} (#{provider_name})"
            end
          elsif count > 5
            puts "    - #{models.first(3).map do |m|
              m[:name]
            end.join(', ')}, and #{count - 3} more..."
          end
        end
        puts ''
      end

      # Configure model preferences interactively
      def configure_model_preferences
        MODEL_CATEGORIES.each do |category, info|
          models = @available_models[category] || []

          if models.empty?
            if info[:required]
              @logger.warn("No #{info[:name].downcase} available. Some features may not work.")
            end
            next
          end

          configure_category_models(category, info, models)
        end
      end

      # Configure models for a specific category
      #
      # @param category [Symbol] Model category
      # @param info [Hash] Category information
      # @param models [Array] Available models for category
      def configure_category_models(category, info, models)
        puts "\n🤖 #{info[:name]} Configuration"
        puts "Purpose: #{info[:description]}"

        if models.size == 1
          # Auto-select single model
          model = models.first
          @selected_models[category] = model
          @logger.info("Auto-selected: #{model[:name]} (#{model[:provider]})")
          return
        end

        # Group models by provider
        models_by_provider = group_models_by_provider(models)

        if models_by_provider.size == 1
          # Only one provider, show models directly
          provider_key = models_by_provider.keys.first
          select_model_from_provider(category, info, provider_key, models_by_provider[provider_key])
        else
          # Multiple providers, let user choose provider first
          select_model_with_provider_separation(category, info, models_by_provider)
        end

        # Show additional model info
        return unless @selected_models[category]

        display_model_details(@selected_models[category]) if @prompt.yes?('Show model details?',
                                                                          default: false)
      end

      # Group models by provider for organized selection
      #
      # @param models [Array] Available models
      # @return [Hash] Models grouped by provider
      def group_models_by_provider(models)
        models.group_by { |model| model[:provider] }
      end

      # Select model when only one provider is available
      #
      # @param category [Symbol] Model category
      # @param info [Hash] Category information
      # @param provider [String] Provider name
      # @param provider_models [Array] Models from this provider
      def select_model_from_provider(category, info, provider, provider_models)
        provider_name = get_provider_display_name(provider)
        puts "\nAvailable #{info[:name].downcase} from #{provider_name}:"

        choices = build_model_choices(provider_models)

        selected = @prompt.select(
          "Choose #{info[:name].downcase}:",
          choices,
          cycle: true,
          filter: true,
          help: '(Use ↑/↓ arrows to navigate, Enter to select, type to filter)'
        )

        @selected_models[category] = selected
      end

      # Select model with provider separation for multiple providers
      #
      # @param category [Symbol] Model category
      # @param info [Hash] Category information
      # @param models_by_provider [Hash] Models grouped by provider
      def select_model_with_provider_separation(category, info, models_by_provider)
        # First, let user choose provider
        provider_choices = models_by_provider.map do |provider, provider_models|
          provider_name = get_provider_display_name(provider)
          model_count = provider_models.size
          {
            name: "#{provider_name} (#{model_count} models)",
            value: provider
          }
        end

        selected_provider = @prompt.select(
          "Choose AI provider for #{info[:name].downcase}:",
          provider_choices,
          cycle: true,
          help: '(Use ↑/↓ arrows to navigate, Enter to select)'
        )

        # Then select model from chosen provider
        select_model_from_provider(category, info, selected_provider,
                                   models_by_provider[selected_provider])
      end

      # Build model choices with pricing and capability info
      #
      # @param models [Array] Models to build choices for
      # @return [Array] Formatted choices for TTY::Prompt
      def build_model_choices(models)
        models.map do |model|
          price_info = if model[:input_price]
                         " ($#{model[:input_price]}/1M tokens)"
                       else
                         ''
                       end

          # Add capability indicators
          capabilities = []
          capabilities << '👁️' if model[:supports_vision]
          capabilities << '🔧' if model[:supports_tools]
          capability_info = capabilities.any? ? " #{capabilities.join(' ')}" : ''

          description = "#{model[:name]}#{price_info}#{capability_info}"
          { name: description, value: model }
        end
      end

      # Display detailed information about a model
      #
      # @param model [Hash] Model information
      def display_model_details(model)
        puts "\n📋 Model Details:"
        puts "  ID: #{model[:id]}"
        puts "  Provider: #{model[:provider]}"

        if model[:context_window]
          formatted_window = model[:context_window].to_s.reverse.gsub(/(\d{3})(?=\d)/,
                                                                      '\\1,').reverse
          puts "  Context Window: #{formatted_window} tokens"
        end

        puts '  Vision Support: Yes' if model[:supports_vision]

        puts '  Function Calling: Yes' if model[:supports_tools]

        puts "  Input Cost: $#{model[:input_price]}/1M tokens" if model[:input_price]

        puts "  Output Cost: $#{model[:output_price]}/1M tokens" if model[:output_price]

        puts ''
      end

      # Finalize model configuration
      def finalize_model_configuration
        @setup_data[:models] = {}

        @selected_models.each do |category, model|
          @setup_data[:models][category] = {
            id: model[:id],
            name: model[:name],
            provider: model[:provider],
            capabilities: extract_model_capabilities(model)
          }
        end

        # Set default models for AI configuration
        if @selected_models[:chat]
          @setup_data[:ai] ||= {}
          @setup_data[:ai][:default_model] = @selected_models[:chat][:id]
          @setup_data[:ai][:default_provider] = @selected_models[:chat][:provider]
        end

        if @selected_models[:embedding]
          @setup_data[:ai] ||= {}
          @setup_data[:ai][:default_embedding_model] = @selected_models[:embedding][:id]
        end

        @logger.success('Model configuration completed!')
        display_final_model_summary
      end

      # Extract capabilities from model information
      #
      # @param model [Hash] Model information
      # @return [Array<String>] List of capabilities
      def extract_model_capabilities(model)
        capabilities = []
        capabilities << 'vision' if model[:supports_vision]
        capabilities << 'tools' if model[:supports_tools]
        capabilities << 'embedding' if model[:dimensions]
        capabilities
      end

      # Display final model configuration summary
      def display_final_model_summary
        puts "\n✅ Selected Models:"
        @selected_models.each do |category, model|
          provider_name = get_provider_display_name(model[:provider])
          puts "  #{category.to_s.capitalize}: #{model[:name]} (#{provider_name})"
        end
        puts ''
      end

      # Fallback to default models if discovery fails
      def fallback_to_default_models
        @logger.warn('Using fallback default models...')

        primary_provider = @setup_data[:primary_provider]
        provider_config = @setup_data[:providers][primary_provider]

        case primary_provider
        when :openai, :openrouter
          @available_models[:chat] = [{
            id: 'gpt-4o-mini',
            name: 'GPT-4o Mini',
            provider: 'openai',
            supports_vision: true,
            supports_tools: true
          }]
          @available_models[:embedding] = [{
            id: 'text-embedding-3-small',
            name: 'Text Embedding 3 Small',
            provider: 'openai'
          }]
        when :anthropic
          @available_models[:chat] = [{
            id: 'claude-3-haiku-20240307',
            name: 'Claude 3 Haiku',
            provider: 'anthropic',
            supports_tools: true
          }]
        when :gemini
          @available_models[:chat] = [{
            id: 'gemini-2.0-flash',
            name: 'Gemini 2.0 Flash',
            provider: 'gemini',
            supports_vision: true,
            supports_tools: true
          }]
          @available_models[:embedding] = [{
            id: 'text-embedding-004',
            name: 'Text Embedding 004',
            provider: 'gemini'
          }]
        when :deepseek
          @available_models[:chat] = [{
            id: 'deepseek-chat',
            name: 'DeepSeek Chat',
            provider: 'deepseek',
            supports_tools: true
          }]
        end

        @available_models[:image] = []
      end

      # Get display name for a provider, handling mismatches safely
      #
      # @param provider [String, Symbol] Provider identifier from model
      # @return [String] Human-readable provider name
      def get_provider_display_name(provider)
        provider_key = map_provider_to_key(provider)

        if @setup_data[:providers] && @setup_data[:providers][provider_key]
          @setup_data[:providers][provider_key][:name]
        else
          # Fallback to capitalized provider name
          provider.to_s.capitalize
        end
      end

      # Map model provider to setup data key
      #
      # @param provider [String, Symbol] Provider from model
      # @return [Symbol] Provider key for setup data
      def map_provider_to_key(provider)
        case provider.to_s.downcase
        when 'openai'
          # Could be either openai or openrouter
          if @setup_data[:providers]&.key?(:openrouter) && !@setup_data[:providers]&.key?(:openai)
            :openrouter
          else
            :openai
          end
        when 'google', 'gemini'
          :gemini
        when 'anthropic'
          :anthropic
        when 'deepseek'
          :deepseek
        else
          provider.to_sym
        end
      end
    end
  end
end
