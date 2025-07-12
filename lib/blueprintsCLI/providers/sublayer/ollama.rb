# frozen_string_literal: true

module Sublayer
  module Providers
    class Ollama
      ##
      # Makes a POST request to an Ollama API endpoint to process a prompt and returns the adapted response.
      #
      # This method sends a user prompt to a specified model hosted at a given endpoint,
      # processes the response through an output adapter, and returns the adapted result.
      # It's designed to work with Ollama-compatible APIs that support function calling.
      #
      # @param host [String] The base URL of the API endpoint to send the request to
      # @param model [String] The identifier of the model to use for processing the prompt
      # @param prompt [String] The user input or question to be processed by the model
      # @param output_adapter [Object] An adapter object that must respond to:
      #   - +format_properties+: Returns properties hash for the response format
      #   - +format_required+: Returns array of required fields
      #   - +name+: Returns the name of the expected response field
      #
      # @return [Object] The adapted response from the API, specifically the value
      #   associated with the output_adapter's name in the function call arguments
      #
      # @raise [RuntimeError] If no function is called in the API response (message doesn't contain tool_calls)
      #
      # @example Basic usage with a JSON output adapter
      #   class JsonAdapter
      #     def self.format_properties
      #       { data: { type: "object" } }
      #     end
      #
      #     def self.format_required
      #       ["data"]
      #     end
      #
      #     def self.name
      #       "json_response"
      #     end
      #   end
      #
      #   response = Sublayer::Providers::Ollama.call(
      #     host: "https://api.ollama.example.com",
      #     model: "text-model-001",
      #     prompt: "Explain Ruby modules",
      #     output_adapter: JsonAdapter
      #   )
      #
      # @example Handling the response
      #   begin
      #     response = Sublayer::Providers::Ollama.call(
      #       host: "https://api.ollama.example.com",
      #       model: "text-model-001",
      #       prompt: "What's the weather today?",
      #       output_adapter: WeatherAdapter
      #     )
      #     puts "API Response: #{response}"
      #   rescue => e
      #     puts "Error processing request: #{e.message}"
      #   end
      #
      # @note The output_adapter parameter must be an object that implements the required interface
      #   (format_properties, format_required, and name methods)
      #
      # @note This method expects the API to return a response with a message containing tool_calls
      def self.call(host:, model:, prompt:, output_adapter:)
        response = HTTParty.post(
          "#{host}",
          body: {
            model: '#{model}',
            messages: [
              {
                role: 'user',
                content: prompt
              }
            ],
            stream: false,
            tools: [
              {
                type: 'function',
                function: {
                  name: 'response',
                  parameters: {
                    type: 'object',
                    properties: output_adapter.format_properties,
                    required: output_adapter.format_required
                  }
                }
              }
            ]
          }.to_json
        )

        message = response['message']

        raise 'No function called' unless message['tool_calls'].length > 0

        function_body = message.dig('tool_calls', 0, 'function', 'arguments')
        function_body[output_adapter.name]
      end
    end
  end
end
