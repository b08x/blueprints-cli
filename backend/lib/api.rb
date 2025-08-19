# frozen_string_literal: true

require 'sinatra/base'
require 'json'

# Load the existing blueprintsCLI infrastructure
require 'blueprintsCLI/config/environment'
require 'blueprintsCLI/db/models/blueprint'
require 'blueprintsCLI/db/models/category'
require 'blueprintsCLI/services/blueprint_service'

module BlueprintsCLI
  class API < Sinatra::Base
    configure do
      set :bind, '0.0.0.0'
      set :port, 3000
      enable :logging
    end

    # JSON content type for all responses
    before do
      content_type :json
    end

    # Health check endpoint
    get '/health' do
      {
        status: 'ok',
        timestamp: Time.now.iso8601,
        service: 'blueprints-api'
      }.to_json
    end

    # Get all blueprints or search
    get '/api/blueprints' do
      service = BlueprintService.new
      query = params['query']
      blueprints = service.search(query)

      {
        blueprints: blueprints,
        total: blueprints.length,
        query: query
      }.to_json
    rescue StandardError => e
      status 500
      { error: 'Failed to fetch blueprints', message: e.message }.to_json
    end

    # Get specific blueprint by ID
    get '/api/blueprints/:id' do
      blueprint = Blueprint[params[:id].to_i]
      if blueprint
        blueprint_data = blueprint.to_hash.merge(
          categories: blueprint.categories.map(&:to_hash)
        )
        blueprint_data.to_json
      else
        status 404
        { error: 'Blueprint not found' }.to_json
      end
    rescue StandardError => e
      status 500
      { error: 'Failed to fetch blueprint', message: e.message }.to_json
    end

    # Create new blueprint
    post '/api/blueprints' do
      data = JSON.parse(request.body.read)
      service = BlueprintService.new
      blueprint = service.create(data)
      status 201
      blueprint.to_json
    rescue JSON::ParserError
      status 400
      { error: 'Invalid JSON' }.to_json
    rescue StandardError => e
      status 500
      { error: 'Failed to create blueprint', message: e.message }.to_json
    end

    # Generate code from prompt (AI endpoint)
    post '/api/blueprints/generate' do
      data = JSON.parse(request.body.read)
      prompt = data['prompt']
      language = data['language'] || 'javascript'
      framework = data['framework'] || 'react'

      # Use existing AI generation if available, otherwise mock
      if defined?(BlueprintsCLI::Services::AICodeGenerator)
        generator = BlueprintsCLI::Services::AICodeGenerator.new
        result = generator.generate_code(
          prompt: prompt,
          language: language,
          framework: framework
        )
      else
        # Fallback to mock generation
        result = generate_mock_code(prompt, language, framework)
      end

      {
        code: result[:code] || result,
        language: language,
        framework: framework,
        prompt: prompt,
        generated_at: Time.now.iso8601
      }.to_json
    rescue JSON::ParserError
      status 400
      { error: 'Invalid JSON' }.to_json
    rescue StandardError => e
      status 500
      { error: 'Code generation failed', message: e.message }.to_json
    end

    # Generate metadata from code (AI endpoint)
    post '/api/blueprints/metadata' do
      data = JSON.parse(request.body.read)
      code = data['code']

      metadata = generate_metadata_from_code(code)
      metadata.to_json
    rescue JSON::ParserError
      status 400
      { error: 'Invalid JSON' }.to_json
    rescue StandardError => e
      status 500
      { error: 'Metadata generation failed', message: e.message }.to_json
    end

    # Error handlers
    not_found do
      { error: 'API endpoint not found' }.to_json
    end

    error do
      { error: 'Internal server error' }.to_json
    end

    private

    # Mock code generation for development
    def generate_mock_code(prompt, language, framework)
      case framework.downcase
      when 'react'
        {
          code: <<~CODE
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
        }
      when 'vue'
        {
          code: <<~CODE
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
        }
      else
        {
          code: "// Generated code for: #{prompt}\n// Language: #{language}\n// Framework: #{framework}\n\nconsole.log('Generated code placeholder');"
        }
      end
    end

    # Mock metadata generation
    def generate_metadata_from_code(code)
      {
        name: 'AI Generated Blueprint',
        description: 'A blueprint automatically generated from the provided code snippet using AI analysis.',
        language: detect_language(code),
        framework: detect_framework(code),
        categories: suggest_categories(code),
        complexity: estimate_complexity(code),
        estimated_lines: code.lines.count,
        generated_at: Time.now.iso8601
      }
    end

    def detect_language(code)
      if code.match?(/\b(function|const|let|var|=>)\b/) || code.include?('console.log')
        return 'javascript'
      end
      if code.match?(/\bdef\s+\w+/) || code.include?('import ') || code.include?('print(')
        return 'python'
      end
      return 'ruby' if code.match?(/\b(def|class|require)\b/) || code.include?('puts ')
      return 'html' if code.include?('<') && code.include?('>')
      return 'css' if code.include?('{') && code.include?('}') && code.include?(':')

      'unknown'
    end

    def detect_framework(code)
      return 'react' if code.include?('React') || code.include?('jsx') || code.include?('useState')
      return 'vue' if code.include?('<template>') || code.include?('Vue')
      return 'angular' if code.include?('@Component') || code.include?('Angular')
      return 'sinatra' if code.include?('Sinatra') || code.match?(/get\s+['"]/)
      return 'rails' if code.include?('Rails') || code.include?('ActiveRecord')

      'none'
    end

    def suggest_categories(code)
      categories = []
      categories << 'component' if code.include?('Component') || code.include?('export default')
      if code.include?('fetch') || code.include?('axios') || code.include?('request')
        categories << 'api'
      end
      categories << 'utility' if code.match?(/\bfunction\b/) && !code.include?('Component')
      if code.match?(/\b(SELECT|INSERT|UPDATE|DELETE)\b/i) || code.include?('query')
        categories << 'database'
      end
      if code.include?('http') || code.include?('server') || code.include?('route')
        categories << 'web'
      end
      categories.any? ? categories : ['general']
    end

    def estimate_complexity(code)
      lines = code.lines.count
      return 'simple' if lines < 20
      return 'medium' if lines < 100

      'complex'
    end
  end
end
