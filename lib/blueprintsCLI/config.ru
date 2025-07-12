# frozen_string_literal: true

require 'rack'
require 'sequel'
require 'json'

# Load environment
require_relative 'config/environment'

# Load models
require_relative 'db/models/blueprint'
require_relative 'db/models/category'

# Load services
require_relative 'db/services/blueprint_service'

# Main application class to handle API requests
class App
  def call(env)
    req = Rack::Request.new(env)
    # Handle CORS preflight requests
    if req.options?
      return [
        200,
        {
          'Access-Control-Allow-Origin' => '*',
          'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers' => 'Content-Type'
        },
        []
      ]
    end

    # Route requests based on path
    case req.path_info
    when '/blueprints'
      handle_blueprints_request(req)
    else
      [404, { 'Content-Type' => 'application/json' }, ['{"error": "Not Found"}']]
    end
  end

  private

  def handle_blueprints_request(req)
    service = BlueprintService.new
    headers = { 'Content-Type' => 'application/json', 'Access-Control-Allow-Origin' => '*' }

    if req.get?
      # Handle GET request for searching blueprints
      blueprints = service.search(req.params['query'])
      [200, headers, [blueprints.to_json]]
    elsif req.post?
      # Handle POST request for creating a new blueprint
      begin
        data = JSON.parse(req.body.read)
        blueprint = service.create(data)
        [201, headers, [blueprint.to_json]]
      rescue JSON::ParserError
        [400, headers, ['{"error": "Invalid JSON"}']]
      end
    else
      # Handle other methods
      [405, headers, ['{"error": "Method Not Allowed"}']]
    end
  end
end

# Run the Rack application
run App.new
