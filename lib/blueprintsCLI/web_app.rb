# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative 'config/environment'
require_relative 'db/models/blueprint'
require_relative 'db/models/category'
require_relative 'services/blueprint_service'
require_relative 'services/ai_code_generator'

module BlueprintsCLI
  #
  # Main Sinatra web application for the Blueprints CLI web interface.
  #
  # This application provides:
  # - Static file serving for the web UI
  # - RESTful API endpoints for blueprint management
  # - AI-powered code generation and metadata extraction
  # - CORS support for cross-origin requests
  #
  class WebApp < Sinatra::Base
    # Configure Sinatra
    configure do
      set :static, true
      set :public_folder, File.expand_path('public', __dir__)
      set :views, File.expand_path('public', __dir__)
      set :bind, '0.0.0.0'
      set :port, 9292
      
      # Enable logging
      enable :logging
      
      # Set JSON as default content type for API responses
      before '/api/*' do
        content_type :json
        headers 'Access-Control-Allow-Origin' => '*',
                'Access-Control-Allow-Methods' => 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers' => 'Content-Type, Authorization'
      end
      
      # Handle CORS preflight requests
      options '*' do
        response.headers['Access-Control-Allow-Origin'] = '*'
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        200
      end
    end
    
    # Initialize services
    def initialize(app = nil)
      super(app)
      @blueprint_service = BlueprintService.new
      @ai_generator = BlueprintsCLI::Services::AICodeGenerator.new
    end
    
    # Static file routes for the web UI
    get '/' do
      send_file File.join(settings.public_folder, 'index.html')
    end
    
    get '/generator' do
      send_file File.join(settings.public_folder, 'generator.html')
    end
    
    get '/submission' do
      send_file File.join(settings.public_folder, 'submission.html')
    end
    
    get '/viewer' do
      send_file File.join(settings.public_folder, 'viewer.html')
    end
    
    # Test route for frontend validation
    get '/test' do
      send_file File.join(__dir__, 'test_frontend.html')
    end
    
    # API Routes
    
    # GET /api/blueprints - Search and list blueprints
    get '/api/blueprints' do
      begin
        query = params['query']
        blueprints = @blueprint_service.search(query)
        
        {
          blueprints: blueprints,
          total: blueprints.length,
          query: query
        }.to_json
      rescue => e
        status 500
        { error: "Failed to fetch blueprints: #{e.message}" }.to_json
      end
    end
    
    # POST /api/blueprints - Create a new blueprint
    post '/api/blueprints' do
      begin
        data = JSON.parse(request.body.read)
        
        # Validate required fields
        unless data['name'] && data['description'] && data['code']
          status 400
          return { error: 'Missing required fields: name, description, code' }.to_json
        end
        
        blueprint = @blueprint_service.create(data)
        
        status 201
        blueprint.to_json
      rescue JSON::ParserError
        status 400
        { error: 'Invalid JSON in request body' }.to_json
      rescue => e
        status 500
        { error: "Failed to create blueprint: #{e.message}" }.to_json
      end
    end
    
    # GET /api/blueprints/:id - Get a specific blueprint
    get '/api/blueprints/:id' do
      begin
        blueprint_id = params['id'].to_i
        blueprint = Blueprint[blueprint_id]
        
        if blueprint
          blueprint_data = blueprint.to_hash.merge(
            categories: blueprint.categories.map(&:to_hash)
          )
          blueprint_data.to_json
        else
          status 404
          { error: 'Blueprint not found' }.to_json
        end
      rescue => e
        status 500
        { error: "Failed to fetch blueprint: #{e.message}" }.to_json
      end
    end
    
    # POST /api/blueprints/generate - AI code generation
    post '/api/blueprints/generate' do
      begin
        data = JSON.parse(request.body.read)
        
        unless data['prompt']
          status 400
          return { error: 'Missing required field: prompt' }.to_json
        end
        
        result = @ai_generator.generate_code(
          prompt: data['prompt'],
          language: data['language'] || 'javascript',
          framework: data['framework'] || 'react',
          options: data['options'] || {}
        )
        
        if result[:success]
          result.to_json
        else
          status 500
          result.to_json
        end
      rescue JSON::ParserError
        status 400
        { error: 'Invalid JSON in request body' }.to_json
      rescue => e
        status 500
        { error: "Code generation failed: #{e.message}" }.to_json
      end
    end
    
    # POST /api/blueprints/metadata - AI metadata generation
    post '/api/blueprints/metadata' do
      begin
        data = JSON.parse(request.body.read)
        
        unless data['code']
          status 400
          return { error: 'Missing required field: code' }.to_json
        end
        
        result = @ai_generator.generate_metadata(data['code'])
        
        if result[:success]
          result.to_json
        else
          status 500
          result.to_json
        end
      rescue JSON::ParserError
        status 400
        { error: 'Invalid JSON in request body' }.to_json
      rescue => e
        status 500
        { error: "Metadata generation failed: #{e.message}" }.to_json
      end
    end
    
    # Health check endpoint
    get '/api/health' do
      {
        status: 'ok',
        timestamp: Time.now.iso8601,
        version: '1.0.0'
      }.to_json
    end
    
    # 404 handler
    not_found do
      if request.path.start_with?('/api/')
        content_type :json
        { error: 'API endpoint not found' }.to_json
      else
        '<h1>404 - Page Not Found</h1>'
      end
    end
    
    # Error handlers
    error 400 do
      content_type :json
      { error: 'Bad Request' }.to_json
    end
    
    error 500 do
      content_type :json
      { error: 'Internal Server Error' }.to_json
    end
    
    # Development helper routes
    if development?
      get '/api/debug/info' do
        {
          environment: ENV['RACK_ENV'] || 'development',
          database_connected: DB.test_connection,
          blueprint_count: Blueprint.count,
          category_count: Category.count
        }.to_json
      end
    end
  end
end