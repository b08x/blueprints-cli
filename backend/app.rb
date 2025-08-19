# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require 'rack'
require 'dry-monads'

# Load all dependencies
require_relative 'config/environment'
require_relative 'lib/models/blueprint'
require_relative 'lib/models/category'
require_relative 'lib/services/blueprint_service'
require_relative 'lib/services/ai_service'
require_relative 'lib/middleware/authentication'
require_relative 'lib/middleware/rate_limiter'
require_relative 'lib/middleware/json_body_parser'

module BlueprintsCLI
  #
  # Main API application for the Blueprints CLI backend service.
  #
  # This application provides:
  # - RESTful API endpoints for blueprint management
  # - AI-powered code generation and analysis
  # - Authentication and authorization
  # - Rate limiting and security headers
  #
  class API < Sinatra::Base
    # Configure Sinatra
    configure do
      set :environment, ENV['RACK_ENV'] || 'development'
      set :bind, '0.0.0.0'
      set :port, ENV['PORT'] || 4000
      set :logging, true
      set :dump_errors, development?
      set :show_exceptions, development?
    end

    # Global middleware
    use Rack::JSONBodyParser
    use BlueprintsCLI::Middleware::RateLimiter

    # API versioning and content type
    before '/api/v1/*' do
      content_type :json

      # Add security headers
      headers 'X-Content-Type-Options' => 'nosniff'
      headers 'X-Frame-Options' => 'DENY'
      headers 'X-XSS-Protection' => '1; mode=block'
    end

    # Initialize services
    def initialize(app = nil)
      super
      @blueprint_service = BlueprintsCLI::Services::BlueprintService.new
      @ai_service = BlueprintsCLI::Services::AIService.new
    end

    # Health check endpoint
    get '/api/health' do
      {
        status: 'ok',
        timestamp: Time.now.iso8601,
        version: '2.0.0',
        environment: ENV.fetch('RACK_ENV', nil),
        services: {
          database: check_database_health,
          redis: check_redis_health
        }
      }.to_json
    end

    # API version info
    get '/api/v1' do
      {
        name: 'BlueprintsCLI API',
        version: '1.0.0',
        endpoints: {
          blueprints: '/api/v1/blueprints',
          categories: '/api/v1/categories',
          ai: '/api/v1/ai',
          search: '/api/v1/search'
        }
      }.to_json
    end

    # Blueprint endpoints
    get '/api/v1/blueprints' do
      params = parse_query_params(request.params)
      result = @blueprint_service.list(params)

      {
        blueprints: result[:blueprints],
        pagination: result[:pagination],
        filters: params
      }.to_json
    rescue StandardError => e
      handle_error(e, 'Failed to fetch blueprints')
    end

    post '/api/v1/blueprints' do
      data = parse_request_body
      validate_blueprint_data(data)

      blueprint = @blueprint_service.create(data)

      status 201
      {
        blueprint: blueprint.to_hash,
        message: 'Blueprint created successfully'
      }.to_json
    rescue ValidationError => e
      status 400
      { error: 'Validation failed', details: e.errors }.to_json
    rescue StandardError => e
      handle_error(e, 'Failed to create blueprint')
    end

    get '/api/v1/blueprints/:id' do
      blueprint = @blueprint_service.find(params['id'])

      if blueprint
        {
          blueprint: blueprint.to_hash.merge(
            categories: blueprint.categories.map(&:to_hash),
            related: @blueprint_service.find_related(blueprint.id, limit: 5)
          )
        }.to_json
      else
        status 404
        { error: 'Blueprint not found' }.to_json
      end
    rescue StandardError => e
      handle_error(e, 'Failed to fetch blueprint')
    end

    put '/api/v1/blueprints/:id' do
      data = parse_request_body
      blueprint = @blueprint_service.update(params['id'], data)

      if blueprint
        { blueprint: blueprint.to_hash }.to_json
      else
        status 404
        { error: 'Blueprint not found' }.to_json
      end
    rescue StandardError => e
      handle_error(e, 'Failed to update blueprint')
    end

    delete '/api/v1/blueprints/:id' do
      success = @blueprint_service.delete(params['id'])

      if success
        status 204
      else
        status 404
        { error: 'Blueprint not found' }.to_json
      end
    rescue StandardError => e
      handle_error(e, 'Failed to delete blueprint')
    end

    # AI endpoints
    post '/api/v1/ai/generate' do
      data = parse_request_body
      validate_ai_request(data)

      result = @ai_service.generate_code(
        prompt: data['prompt'],
        language: data['language'] || 'javascript',
        framework: data['framework'],
        options: data['options'] || {}
      )

      result.to_json
    rescue StandardError => e
      handle_error(e, 'Code generation failed')
    end

    post '/api/v1/ai/analyze' do
      data = parse_request_body

      unless data['code']
        status 400
        return { error: 'Code is required for analysis' }.to_json
      end

      result = @ai_service.analyze_code(data['code'])
      result.to_json
    rescue StandardError => e
      handle_error(e, 'Code analysis failed')
    end

    # Search endpoints
    get '/api/v1/search' do
      query = params['q'] || ''
      options = {
        limit: [params['limit']&.to_i || 20, 100].min,
        offset: params['offset']&.to_i || 0,
        language: params['language'],
        framework: params['framework'],
        categories: params['categories']&.split(',')
      }

      result = @blueprint_service.search(query, options)

      {
        results: result[:blueprints],
        total: result[:total],
        query: query,
        facets: result[:facets],
        pagination: {
          limit: options[:limit],
          offset: options[:offset],
          total: result[:total]
        }
      }.to_json
    rescue StandardError => e
      handle_error(e, 'Search failed')
    end

    # Error handlers
    not_found do
      content_type :json
      { error: 'Endpoint not found', path: request.path_info }.to_json
    end

    error 500 do
      content_type :json
      {
        error: 'Internal server error',
        request_id: env['HTTP_X_REQUEST_ID']
      }.to_json
    end

    private

    def parse_request_body
      request.body.rewind
      body = request.body.read
      return {} if body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      halt 400, { error: 'Invalid JSON in request body' }.to_json
    end

    def parse_query_params(params)
      {
        limit: [params['limit']&.to_i || 20, 100].min,
        offset: params['offset']&.to_i || 0,
        sort: params['sort'] || 'created_at',
        order: %w[asc desc].include?(params['order']) ? params['order'] : 'desc',
        language: params['language'],
        framework: params['framework'],
        categories: params['categories']&.split(','),
        search: params['q']
      }.compact
    end

    def validate_blueprint_data(data)
      errors = []

      errors << 'name is required' unless data['name']&.strip&.length&.> 0
      errors << 'description is required' unless data['description']&.strip&.length&.> 0
      errors << 'code is required' unless data['code']&.strip&.length&.> 0
      errors << 'language is required' unless data['language']&.strip&.length&.> 0

      return unless errors.any?

      raise ValidationError.new(errors)
    end

    def validate_ai_request(data)
      return if data['prompt']&.strip&.length&.> 0

      halt 400, { error: 'prompt is required' }.to_json
    end

    def handle_error(error, message)
      LOGGER.error "#{message}: #{error.message}"
      LOGGER.error error.backtrace.join("\n") if development?

      status 500
      {
        error: message,
        details: development? ? error.message : nil,
        request_id: env['HTTP_X_REQUEST_ID'],
        timestamp: Time.now.iso8601
      }.compact.to_json
    end

    def check_database_health
      DB.test_connection
      { status: 'healthy', connected: true }
    rescue StandardError => e
      LOGGER.warn "Database health check failed: #{e.message}"
      { status: 'unhealthy', error: e.message }
    end

    def check_redis_health
      REDIS.ping
      { status: 'healthy', connected: true }
    rescue StandardError => e
      LOGGER.warn "Redis health check failed: #{e.message}"
      { status: 'unhealthy', error: e.message }
    end
  end

  class ValidationError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(errors.join(', '))
    end
  end
end
