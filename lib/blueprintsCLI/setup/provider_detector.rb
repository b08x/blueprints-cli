# frozen_string_literal: true

require 'ruby_llm'

module BlueprintsCLI
  module Setup
    # ProviderDetector handles AI provider detection, configuration, and testing.
    # It scans environment variables for API keys, guides users through provider
    # selection, and tests connections to ensure providers are working correctly.
    class ProviderDetector
      # Provider information including environment variables and capabilities
      PROVIDERS = {
        openai: {
          name: 'OpenAI',
          env_vars: %w[OPENAI_API_KEY],
          description: 'Industry-leading GPT models with excellent performance',
          models: ['gpt-4o', 'gpt-4o-mini', 'gpt-3.5-turbo'],
          capabilities: %w[chat embedding image_generation tools],
          pricing: 'Mid-range',
          notes: 'Direct OpenAI API access'
        },
        openrouter: {
          name: 'OpenRouter',
          env_vars: %w[OPENROUTER_API_KEY],
          description: 'Access to multiple providers through single API',
          models: ['gpt-4o', 'claude-3-5-sonnet', 'llama-3.1-70b'],
          capabilities: %w[chat embedding],
          pricing: 'Variable by model',
          notes: 'Unified access to multiple AI providers'
        },
        anthropic: {
          name: 'Anthropic',
          env_vars: %w[ANTHROPIC_API_KEY],
          description: 'Claude models known for safety and reasoning',
          models: ['claude-3-5-sonnet', 'claude-3-haiku', 'claude-3-opus'],
          capabilities: %w[chat tools],
          pricing: 'Mid-range',
          notes: 'Direct Anthropic API access'
        },
        gemini: {
          name: 'Google Gemini',
          env_vars: %w[GEMINI_API_KEY GOOGLE_API_KEY],
          description: 'Google\'s multimodal AI with competitive pricing',
          models: ['gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'],
          capabilities: %w[chat embedding image_generation tools vision],
          pricing: 'Low-cost',
          notes: 'Excellent for cost-conscious applications'
        },
        deepseek: {
          name: 'DeepSeek',
          env_vars: %w[DEEPSEEK_API_KEY],
          description: 'High-performance reasoning models at low cost',
          models: %w[deepseek-chat deepseek-coder],
          capabilities: %w[chat tools],
          pricing: 'Very low-cost',
          notes: 'Excellent reasoning capabilities'
        }
      }.freeze

      # Initialize the provider detector
      #
      # @param prompt [TTY::Prompt] TTY prompt instance
      # @param setup_data [Hash] Setup data storage
      def initialize(prompt, setup_data)
        @prompt = prompt
        @setup_data = setup_data
        @logger = BlueprintsCLI.logger
        @detected_providers = {}
      end

      # Detect available providers and guide user through configuration
      #
      # @return [Boolean] True if at least one provider was configured
      def detect_and_configure
        @logger.info('Scanning for AI provider API keys...')

        scan_environment_variables
        display_detected_providers

        if @detected_providers.any?
          configure_detected_providers
        else
          guide_manual_configuration
        end

        finalize_provider_configuration
      end

      private

      # Scan environment variables for provider API keys
      def scan_environment_variables
        PROVIDERS.each do |provider_key, provider_info|
          provider_info[:env_vars].each do |env_var|
            next unless ENV[env_var] && !ENV[env_var].empty?

            @detected_providers[provider_key] = {
              info: provider_info,
              api_key: ENV.fetch(env_var, nil),
              env_var: env_var
            }
            @logger.success("Found #{provider_info[:name]} API key (#{env_var})")
            break # Use first found key for this provider
          end
        end
      end

      # Display information about detected providers
      def display_detected_providers
        if @detected_providers.any?
          puts "\n🔍 Detected AI Providers:"
          @detected_providers.each_value do |config|
            info = config[:info]
            puts "  ✓ #{info[:name]} - #{info[:description]}"
            puts "    Models: #{info[:models].join(', ')}"
            puts "    Pricing: #{info[:pricing]}"
            puts ''
          end
        else
          puts "\n❌ No AI provider API keys found in environment variables."
          puts "Don't worry! We'll help you configure providers manually."
        end
      end

      # Configure detected providers
      #
      # @return [Boolean] True if configuration completed
      def configure_detected_providers
        selected_providers = {}

        if @detected_providers.size == 1
          # Auto-select single provider
          provider_key = @detected_providers.keys.first
          selected_providers[provider_key] = @detected_providers[provider_key]
          @logger.info("Auto-selecting #{@detected_providers[provider_key][:info][:name]}")
        else
          # Let user choose from detected providers
          selected_providers = prompt_provider_selection
        end

        configure_providers(selected_providers)
      end

      # Prompt user to select from detected providers
      #
      # @return [Hash] Selected providers configuration
      def prompt_provider_selection
        selected = {}

        puts "\n🤖 Multiple AI providers detected. Choose which ones to configure:"

        @detected_providers.each do |provider_key, config|
          info = config[:info]
          use_provider = @prompt.yes?("Configure #{info[:name]}?", default: true)

          next unless use_provider

          selected[provider_key] = config

          # Test the provider connection
          if test_provider_connection(provider_key, config[:api_key])
            @logger.success("#{info[:name]} connection verified!")
          else
            @logger.failure("#{info[:name]} connection failed")
            use_anyway = @prompt.yes?("Continue with #{info[:name]} anyway?", default: false)
            selected.delete(provider_key) unless use_anyway
          end
        end

        selected
      end

      # Guide user through manual provider configuration
      #
      # @return [Boolean] True if manual configuration completed
      def guide_manual_configuration
        puts "\n🔧 Manual Provider Configuration"
        puts 'Please choose an AI provider to configure:'

        # Display all available providers
        provider_choices = PROVIDERS.map do |key, info|
          { name: "#{info[:name]} - #{info[:description]}", value: key }
        end
        provider_choices << { name: 'Skip provider setup for now', value: :skip }

        selected_provider = @prompt.select('Select a provider:', provider_choices)
        return true if selected_provider == :skip

        configure_manual_provider(selected_provider)
      end

      # Configure a provider manually
      #
      # @param provider_key [Symbol] Provider identifier
      # @return [Boolean] True if configuration completed
      def configure_manual_provider(provider_key)
        provider_info = PROVIDERS[provider_key]

        puts "\n📋 Configuring #{provider_info[:name]}"
        puts "Description: #{provider_info[:description]}"
        puts "Required environment variable: #{provider_info[:env_vars].first}"
        puts ''

        api_key = @prompt.mask("Enter your #{provider_info[:name]} API key:")

        if api_key.empty?
          @logger.warn("No API key provided for #{provider_info[:name]}")
          return false
        end

        # Test the connection
        if test_provider_connection(provider_key, api_key)
          @logger.success("#{provider_info[:name]} connection verified!")
          store_manual_provider(provider_key, api_key)
          true
        else
          @logger.failure("Failed to connect to #{provider_info[:name]}")
          retry_config = @prompt.yes?('Retry configuration?', default: true)
          retry_config ? configure_manual_provider(provider_key) : false
        end
      end

      # Store manually configured provider
      #
      # @param provider_key [Symbol] Provider identifier
      # @param api_key [String] API key
      def store_manual_provider(provider_key, api_key)
        @detected_providers[provider_key] = {
          info: PROVIDERS[provider_key],
          api_key: api_key,
          env_var: PROVIDERS[provider_key][:env_vars].first
        }
      end

      # Test provider connection
      #
      # @param provider_key [Symbol] Provider identifier
      # @param api_key [String] API key to test
      # @return [Boolean] True if connection successful
      def test_provider_connection(provider_key, api_key)
        @logger.info("Testing #{PROVIDERS[provider_key][:name]} connection...")

        # Configure RubyLLM for testing
        original_config = backup_rubyllm_config
        configure_rubyllm_for_test(provider_key, api_key)

        begin
          # Simple test request
          chat = RubyLLM.chat(
            model: get_test_model(provider_key),
            provider: map_provider_for_rubyllm(provider_key)
          )
          response = chat.ask("Hello! Please respond with just 'OK'")

          success = response&.content&.include?('OK')
          @logger.debug("Test response: #{response&.content}") if ENV['DEBUG']
          success
        rescue StandardError => e
          @logger.debug("Connection test failed: #{e.message}") if ENV['DEBUG']
          false
        ensure
          restore_rubyllm_config(original_config)
        end
      end

      # Get appropriate test model for provider
      #
      # @param provider_key [Symbol] Provider identifier
      # @return [String] Model name for testing
      def get_test_model(provider_key)
        case provider_key
        when :openai, :openrouter
          'gpt-4o-mini'
        when :anthropic
          'claude-3-haiku-20240307'
        when :gemini
          'gemini-2.0-flash'
        when :deepseek
          'deepseek-chat'
        else
          'gpt-4o-mini'
        end
      end

      # Map provider key to RubyLLM provider format
      #
      # @param provider_key [Symbol] Provider identifier
      # @return [Symbol] RubyLLM provider symbol
      def map_provider_for_rubyllm(provider_key)
        case provider_key
        when :openrouter
          :openai # OpenRouter uses OpenAI API format
        else
          provider_key
        end
      end

      # Configure RubyLLM for testing
      #
      # @param provider_key [Symbol] Provider identifier
      # @param api_key [String] API key
      def configure_rubyllm_for_test(provider_key, api_key)
        RubyLLM.configure do |config|
          case provider_key
          when :openai
            config.openai_api_key = api_key
          when :openrouter
            config.openai_api_key = api_key
            config.openai_api_base = 'https://openrouter.ai/api/v1'
          when :anthropic
            config.anthropic_api_key = api_key
          when :gemini
            config.gemini_api_key = api_key
          when :deepseek
            config.deepseek_api_key = api_key
          end
        end
      end

      # Backup current RubyLLM configuration
      #
      # @return [Hash] Current configuration
      def backup_rubyllm_config
        {
          openai_api_key: RubyLLM.config.openai_api_key,
          openai_api_base: RubyLLM.config.openai_api_base,
          anthropic_api_key: RubyLLM.config.anthropic_api_key,
          gemini_api_key: RubyLLM.config.gemini_api_key,
          deepseek_api_key: RubyLLM.config.deepseek_api_key
        }
      end

      # Restore RubyLLM configuration
      #
      # @param config [Hash] Configuration to restore
      def restore_rubyllm_config(config)
        RubyLLM.configure do |rubyllm_config|
          config.each do |key, value|
            rubyllm_config.public_send("#{key}=", value) if value
          end
        end
      end

      # Configure selected providers
      #
      # @param providers [Hash] Selected providers configuration
      def configure_providers(providers)
        @setup_data[:providers] = {}

        providers.each do |provider_key, config|
          @setup_data[:providers][provider_key] = {
            name: config[:info][:name],
            api_key: config[:api_key],
            env_var: config[:env_var],
            capabilities: config[:info][:capabilities],
            models: config[:info][:models]
          }
        end
      end

      # Finalize provider configuration
      #
      # @return [Boolean] True if at least one provider configured
      def finalize_provider_configuration
        if @setup_data[:providers]&.any?
          # Select primary provider
          if @setup_data[:providers].size == 1
            primary_provider = @setup_data[:providers].keys.first
          else
            choices = @setup_data[:providers].map do |key, config|
              { name: config[:name], value: key }
            end
            primary_provider = @prompt.select('Select primary AI provider:', choices)
          end

          @setup_data[:primary_provider] = primary_provider
          @logger.success('Provider configuration completed!')
          @logger.info("Primary provider: #{@setup_data[:providers][primary_provider][:name]}")

          true
        else
          @logger.warn('No AI providers configured. Some features may not work.')
          false
        end
      end
    end
  end
end
