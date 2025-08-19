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
require_relative 'services/blueprint_service'

# Main application class to handle both API requests and static file serving
class App
  def initialize
    # Set up static file server for public directory
    @static = Rack::Static.new(proc { [404, {}, []] }, {
      root: File.expand_path('public', __dir__),
      urls: ['/css', '/js', '/images']
    })
  end

  def call(env)
    req = Rack::Request.new(env)
    
    # Handle CORS preflight requests
    if req.options?
      return [
        200,
        {
          'access-control-allow-origin' => '*',
          'access-control-allow-methods' => 'GET, POST, PUT, DELETE, OPTIONS',
          'access-control-allow-headers' => 'content-type, authorization'
        },
        []
      ]
    end

    # Try serving static files first
    static_response = @static.call(env)
    return static_response if static_response[0] != 404

    # Route requests based on path
    case req.path_info
    when '/'
      serve_html_file('index.html')
    when '/generator'
      serve_html_file('generator.html')
    when '/submission'
      serve_html_file('submission.html')
    when '/viewer'
      serve_html_file('viewer.html')
    when '/api/blueprints'
      handle_blueprints_request(req)
    when %r{^/api/blueprints/(\d+)$}
      blueprint_id = $1.to_i
      handle_blueprint_detail_request(req, blueprint_id)
    when '/api/blueprints/generate'
      handle_blueprint_generation_request(req)
    when '/api/blueprints/metadata'
      handle_metadata_generation_request(req)
    else
      [404, { 'content-type' => 'text/html' }, [load_html_file('404.html') || '<h1>404 - Not Found</h1>']]
    end
  end

  private

  def serve_html_file(filename)
    html_content = load_html_file(filename)
    if html_content
      [200, { 'content-type' => 'text/html' }, [html_content]]
    else
      [404, { 'content-type' => 'text/html' }, ['<h1>404 - File Not Found</h1>']]
    end
  end

  def load_html_file(filename)
    file_path = File.expand_path("public/#{filename}", __dir__)
    File.read(file_path) if File.exist?(file_path)
  rescue
    nil
  end

  def cors_headers
    {
      'access-control-allow-origin' => '*',
      'access-control-allow-methods' => 'GET, POST, PUT, DELETE, OPTIONS',
      'access-control-allow-headers' => 'Content-Type, authorization'
    }
  end

  def json_headers
    { 'content-type' => 'application/json' }.merge(cors_headers)
  end

  def handle_blueprints_request(req)
    service = BlueprintService.new

    case req.request_method
    when 'GET'
      # Handle GET request for searching blueprints
      blueprints = service.search(req.params['query'])
      [200, json_headers, [blueprints.to_json]]
    when 'POST'
      # Handle POST request for creating a new blueprint
      begin
        data = JSON.parse(req.body.read)
        blueprint = service.create(data)
        [201, json_headers, [blueprint.to_json]]
      rescue JSON::ParserError
        [400, json_headers, ['{"error": "Invalid JSON"}']]
      rescue => e
        [500, json_headers, [{ error: "Internal server error: #{e.message}" }.to_json]]
      end
    else
      [405, json_headers, ['{"error": "Method Not Allowed"}']]
    end
  end

  def handle_blueprint_detail_request(req, blueprint_id)
    return [405, json_headers, ['{"error": "Method Not Allowed"}']] unless req.get?

    begin
      blueprint = Blueprint[blueprint_id]
      if blueprint
        blueprint_data = blueprint.to_hash.merge(categories: blueprint.categories.map(&:to_hash))
        [200, json_headers, [blueprint_data.to_json]]
      else
        [404, json_headers, ['{"error": "Blueprint not found"}']]
      end
    rescue => e
      [500, json_headers, [{ error: "Internal server error: #{e.message}" }.to_json]]
    end
  end

  def handle_blueprint_generation_request(req)
    return [405, json_headers, ['{"error": "Method Not Allowed"}']] unless req.post?

    begin
      data = JSON.parse(req.body.read)
      prompt = data['prompt']
      language = data['language'] || 'javascript'
      framework = data['framework'] || 'react'
      
      # Mock AI generation response - replace with actual AI service integration
      generated_code = generate_code_with_ai(prompt, language, framework)
      
      response = {
        code: generated_code,
        language: language,
        framework: framework,
        prompt: prompt,
        generated_at: Time.now.iso8601
      }
      
      [200, json_headers, [response.to_json]]
    rescue JSON::ParserError
      [400, json_headers, ['{"error": "Invalid JSON"}']]
    rescue => e
      [500, json_headers, [{ error: "Code generation failed: #{e.message}" }.to_json]]
    end
  end

  def handle_metadata_generation_request(req)
    return [405, json_headers, ['{"error": "Method Not Allowed"}']] unless req.post?

    begin
      data = JSON.parse(req.body.read)
      code = data['code']
      
      # Mock metadata generation - replace with actual AI service integration
      metadata = generate_metadata_with_ai(code)
      
      [200, json_headers, [metadata.to_json]]
    rescue JSON::ParserError
      [400, json_headers, ['{"error": "Invalid JSON"}']]
    rescue => e
      [500, json_headers, [{ error: "Metadata generation failed: #{e.message}" }.to_json]]
    end
  end

  # Mock AI code generation - replace with actual AI service
  def generate_code_with_ai(prompt, language, framework)
    case framework.downcase
    when 'react'
      <<~CODE
        import React from 'react';

        const GeneratedComponent = ({ title = 'Generated Component' }) => {
          return (
            <div className="p-4 border rounded-lg">
              <h2 className="text-xl font-bold mb-2">{title}</h2>
              <p>This component was generated based on: #{prompt}</p>
            </div>
          );
        };

        export default GeneratedComponent;
      CODE
    when 'vue'
      <<~CODE
        <template>
          <div class="p-4 border rounded-lg">
            <h2 class="text-xl font-bold mb-2">{{ title }}</h2>
            <p>This component was generated based on: #{prompt}</p>
          </div>
        </template>

        <script>
        export default {
          name: 'GeneratedComponent',
          props: {
            title: {
              type: String,
              default: 'Generated Component'
            }
          }
        }
        </script>
      CODE
    else
      "// Generated code for: #{prompt}\n// Language: #{language}\n// Framework: #{framework}\n\nconsole.log('Generated code placeholder');"
    end
  end

  # Mock AI metadata generation - replace with actual AI service
  def generate_metadata_with_ai(code)
    {
      name: "AI Generated Blueprint",
      description: "A blueprint automatically generated from the provided code snippet using AI analysis.",
      language: detect_language(code),
      framework: detect_framework(code),
      categories: suggest_categories(code),
      complexity: 'medium',
      estimated_lines: code.lines.count,
      generated_at: Time.now.iso8601
    }
  end

  def detect_language(code)
    return 'javascript' if code.include?('function') || code.include?('=>') || code.include?('const') || code.include?('let')
    return 'python' if code.include?('def ') || code.include?('import ') || code.include?('from ')
    return 'ruby' if code.include?('def ') || code.include?('class ') || code.include?('require ')
    'unknown'
  end

  def detect_framework(code)
    return 'react' if code.include?('React') || code.include?('jsx') || code.include?('useState')
    return 'vue' if code.include?('<template>') || code.include?('Vue')
    return 'angular' if code.include?('@Component') || code.include?('Angular')
    'none'
  end

  def suggest_categories(code)
    categories = []
    categories << 'component' if code.include?('Component') || code.include?('export default')
    categories << 'api' if code.include?('fetch') || code.include?('axios') || code.include?('request')
    categories << 'utility' if code.include?('function') && !code.include?('Component')
    categories << 'database' if code.include?('SELECT') || code.include?('INSERT') || code.include?('query')
    categories.any? ? categories : ['general']
  end
end

# Run the Rack application
run App.new
