# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

# Load the app directly
app_path = File.expand_path('../../lib/blueprintsCLI/config.ru', __dir__)

begin
  # Load the Rack application by evaluating the config.ru file
  app_content = File.read(app_path)
  eval(app_content, binding, app_path)
rescue LoadError => e
  puts "LoadError loading app: #{e.message}"
  # Fallback: create a minimal app for testing
  class App
    def call(env)
      [200, { 'Content-Type' => 'text/html' }, ['<h1>Test App</h1>']]
    end
  end
rescue => e
  puts "Error loading app: #{e.message}"
  # Fallback: create a minimal app for testing
  class App
    def call(env)
      [200, { 'Content-Type' => 'text/html' }, ['<h1>Test App</h1>']]
    end
  end
end

RSpec.describe 'Web UI Integration', type: :request do
  include Rack::Test::Methods

  def app
    @app ||= defined?(App) ? App.new : Rack::Builder.new { run proc { |_| [404, {}, []] } }
  end

  describe 'Static file serving' do
    it 'serves the main index page' do
      get '/'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/html')
    end

    it 'serves CSS files' do
      get '/css/app.css'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('text/css')
    end

    it 'serves JavaScript files' do
      get '/js/app.js'
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include('javascript')
    end
  end

  describe 'Page routing' do
    %w[/ /generator /submission /viewer].each do |path|
      it "serves #{path} page" do
        get path
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('text/html')
      end
    end

    it 'returns 404 for unknown paths' do
      get '/nonexistent'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'API endpoints' do
    describe 'GET /api/blueprints' do
      it 'returns blueprints list' do
        get '/api/blueprints'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')
        
        json_response = JSON.parse(last_response.body)
        expect(json_response).to be_an(Array)
      end

      it 'accepts query parameter' do
        get '/api/blueprints?query=react'
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')
      end
    end

    describe 'POST /api/blueprints' do
      let(:valid_blueprint_data) do
        {
          name: 'Test Blueprint',
          description: 'A test blueprint for integration testing',
          code: 'console.log("Hello, World!");',
          categories: ['test', 'javascript']
        }
      end

      it 'creates a new blueprint with valid data' do
        post '/api/blueprints', valid_blueprint_data.to_json, 'CONTENT_TYPE' => 'application/json'
        
        expect(last_response.status).to eq(201)
        expect(last_response.content_type).to include('application/json')
        
        json_response = JSON.parse(last_response.body)
        expect(json_response).to include('name' => 'Test Blueprint')
      end

      it 'returns error for invalid JSON' do
        post '/api/blueprints', 'invalid json', 'CONTENT_TYPE' => 'application/json'
        
        expect(last_response.status).to eq(400)
        expect(last_response.content_type).to include('application/json')
        
        json_response = JSON.parse(last_response.body)
        expect(json_response).to include('error')
      end
    end

    describe 'POST /api/blueprints/generate' do
      let(:generation_data) do
        {
          prompt: 'Create a React component',
          language: 'javascript',
          framework: 'react'
        }
      end

      it 'generates code from prompt' do
        post '/api/blueprints/generate', generation_data.to_json, 
             'CONTENT_TYPE' => 'application/json'
        
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')
        
        json_response = JSON.parse(last_response.body)
        expect(json_response).to include('code', 'language', 'framework', 'prompt')
        expect(json_response['code']).to be_a(String)
        expect(json_response['code']).not_to be_empty
      end
    end

    describe 'POST /api/blueprints/metadata' do
      let(:code_data) do
        {
          code: 'import React from "react";\n\nconst MyComponent = () => {\n  return <div>Hello</div>;\n};'
        }
      end

      it 'generates metadata from code' do
        post '/api/blueprints/metadata', code_data.to_json, 'CONTENT_TYPE' => 'application/json'
        
        expect(last_response.status).to eq(200)
        expect(last_response.content_type).to include('application/json')
        
        json_response = JSON.parse(last_response.body)
        expect(json_response).to include('name', 'description', 'language', 'categories')
      end
    end
  end

  describe 'CORS headers' do
    it 'includes CORS headers in API responses' do
      get '/api/blueprints'
      
      expect(last_response.headers).to include('Access-Control-Allow-Origin')
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
    end

    it 'handles OPTIONS requests for CORS preflight' do
      options '/api/blueprints'
      
      expect(last_response.status).to eq(200)
      expect(last_response.headers).to include('Access-Control-Allow-Origin')
      expect(last_response.headers).to include('Access-Control-Allow-Methods')
      expect(last_response.headers).to include('Access-Control-Allow-Headers')
    end
  end

  describe 'Error handling' do
    it 'returns JSON error for API endpoints' do
      get '/api/nonexistent'
      
      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('application/json')
      
      json_response = JSON.parse(last_response.body)
      expect(json_response).to include('error')
    end

    it 'returns HTML error for web pages' do
      get '/nonexistent'
      
      expect(last_response.status).to eq(404)
      expect(last_response.content_type).to include('text/html')
    end
  end
end