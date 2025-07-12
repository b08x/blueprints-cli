# frozen_string_literal: true

module BlueprintsCLI
  module Config
    def self.load
      # Configure Sublayer using the new unified configuration system
      sublayer_config = BlueprintsCLI.configuration.sublayer_config
      
      Sublayer.configure do |c|
        c.ai_provider = Object.const_get("Sublayer::Providers::#{sublayer_config[:ai_provider]}")
        c.ai_model = sublayer_config[:ai_model]
        c.logger = Sublayer::Logging::JsonLogger.new(File.join(Dir.pwd, 'log', 'sublayer.log'))
      end
    rescue NameError => e
      BlueprintsCLI.logger.failure("Invalid AI provider configuration: #{e.message}")
      raise
    rescue StandardError => e
      BlueprintsCLI.logger.failure("Error loading Sublayer configuration: #{e.message}")
      raise
    end
  end
end
