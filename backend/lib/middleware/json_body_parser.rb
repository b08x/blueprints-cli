# frozen_string_literal: true

module Rack
  ##
  # Middleware to parse JSON request bodies and make them available in params
  #
  class JSONBodyParser
    ##
    # Initialize middleware
    # @param app [Object] Rack application
    def initialize(app)
      @app = app
    end

    ##
    # Process request and parse JSON body
    # @param env [Hash] Rack environment
    # @return [Array] Rack response
    def call(env)
      request = Rack::Request.new(env)

      # Only parse JSON content types
      if json_request?(request)
        begin
          # Read and parse JSON body
          body = request.body.read
          request.body.rewind

          unless body.empty?
            parsed_json = JSON.parse(body, symbolize_names: true)

            # Make parsed JSON available in rack.request.form_hash
            env['rack.request.form_hash'] = stringify_keys(parsed_json)
            env['rack.request.form_input'] = request.body
          end
        rescue JSON::ParserError => e
          # Return 400 for invalid JSON
          return [
            400,
            { 'Content-Type' => 'application/json' },
            [{
              error: 'Invalid JSON in request body',
              details: e.message,
              timestamp: Time.now.iso8601
            }.to_json]
          ]
        end
      end

      @app.call(env)
    end

    private

    ##
    # Check if request contains JSON
    # @param request [Rack::Request] HTTP request
    # @return [Boolean] True if JSON request
    def json_request?(request)
      content_type = request.content_type
      content_type && content_type.include?('application/json')
    end

    ##
    # Convert symbol keys to strings for Rack compatibility
    # @param hash [Hash] Hash with symbol keys
    # @return [Hash] Hash with string keys
    def stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(key, value), result|
          result[key.to_s] = stringify_keys(value)
        end
      when Array
        obj.map { |item| stringify_keys(item) }
      else
        obj
      end
    end
  end
end
