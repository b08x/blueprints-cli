# frozen_string_literal: true

require 'sinatra/base'
require 'json'

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
        service: 'blueprints-api',
        message: 'Backend service running successfully'
      }.to_json
    end

    # Get all blueprints or search (mock data for testing)
    get '/api/blueprints' do
      query = params['query']

      # Mock blueprint data
      mock_blueprints = [
        {
          id: 1,
          name: 'React Button Component',
          description: 'A reusable button component with various styles',
          language: 'javascript',
          framework: 'react',
          updated_at: Time.now.iso8601
        },
        {
          id: 2,
          name: 'Python Data Processor',
          description: 'Utility functions for processing CSV data',
          language: 'python',
          framework: 'none',
          updated_at: (Time.now - 86_400).iso8601
        }
      ]

      filtered_blueprints = if query
                              mock_blueprints.select do |bp|
                                bp[:name].downcase.include?(query.downcase)
                              end
                            else
                              mock_blueprints
                            end

      {
        blueprints: filtered_blueprints,
        total: filtered_blueprints.length,
        query: query
      }.to_json
    rescue StandardError => e
      status 500
      { error: 'Failed to fetch blueprints', message: e.message }.to_json
    end

    # Get specific blueprint by ID (mock)
    get '/api/blueprints/:id' do
      blueprint_id = params[:id].to_i

      mock_blueprint = {
        id: blueprint_id,
        name: "Blueprint #{blueprint_id}",
        description: "A sample blueprint with ID #{blueprint_id}",
        language: 'javascript',
        framework: 'react',
        code: "console.log('Hello from blueprint #{blueprint_id}');",
        categories: [
          { id: 1, name: 'component' },
          { id: 2, name: 'utility' }
        ],
        updated_at: Time.now.iso8601
      }

      mock_blueprint.to_json
    rescue StandardError => e
      status 500
      { error: 'Failed to fetch blueprint', message: e.message }.to_json
    end

    # Create new blueprint (mock)
    post '/api/blueprints' do
      data = JSON.parse(request.body.read)

      new_blueprint = {
        id: rand(1000..9999),
        name: data['name'] || 'New Blueprint',
        description: data['description'] || 'A new blueprint',
        language: data['language'] || 'javascript',
        framework: data['framework'] || 'none',
        code: data['code'] || '// New blueprint code',
        created_at: Time.now.iso8601,
        updated_at: Time.now.iso8601
      }

      status 201
      new_blueprint.to_json
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

      generated_code = generate_mock_code(prompt, language, framework)

      {
        code: generated_code,
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
        <<~CODE
          import React from 'react';

          const GeneratedComponent = ({ title = 'Generated Component' }) => {
            return (
              <div className="p-4 border rounded-lg">
                <h2 className="text-xl font-bold mb-2">{title}</h2>
                <p>This component was generated based on: #{prompt}</p>
                <p>Language: #{language}, Framework: #{framework}</p>
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
              <p>Language: #{language}, Framework: #{framework}</p>
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
        "// Generated code for: #{prompt}\n// Language: #{language}\n// Framework: #{framework}\n\nfunction generatedFunction() {\n  console.log('Generated based on: #{prompt}');\n  return true;\n}\n\nexport { generatedFunction };"
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
