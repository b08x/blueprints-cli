# frozen_string_literal: true

require 'jwt'

module BlueprintsCLI
  module Middleware
    ##
    # JWT Authentication middleware for API endpoints
    # Validates JWT tokens and sets current user context
    #
    class Authentication
      # Public endpoints that don't require authentication
      EXEMPT_PATHS = [
        '/api/health',
        '/api/v1',
        %r{^/api/v1/blueprints$},      # GET only
        %r{^/api/v1/blueprints/\d+$}   # GET only
      ].freeze

      ##
      # Initialize middleware
      # @param app [Object] Rack application
      # @param secret [String] JWT secret key
      def initialize(app, secret: nil)
        @app = app
        @secret = secret || ENV.fetch('JWT_SECRET', 'your-secret-key-change-in-production')
        @logger = LOGGER
      end

      ##
      # Process request
      # @param env [Hash] Rack environment
      # @return [Array] Rack response
      def call(env)
        request = Rack::Request.new(env)

        # Skip authentication for exempt paths and GET requests to public endpoints
        return @app.call(env) if exempt_from_auth?(request)

        # Extract and validate token
        token = extract_token(request)

        return unauthorized_response('Missing authentication token') unless token

        begin
          payload = decode_token(token)

          # Set user context in environment
          env['current_user'] = payload['user']
          env['auth_payload'] = payload

          @logger.info "Authenticated request for user: #{payload['user']['id']}"

          @app.call(env)
        rescue JWT::DecodeError => e
          @logger.warn "Invalid JWT token: #{e.message}"
          unauthorized_response('Invalid authentication token')
        rescue JWT::ExpiredSignature
          @logger.warn 'Expired JWT token'
          unauthorized_response('Authentication token has expired')
        rescue StandardError => e
          @logger.error "Authentication error: #{e.message}"
          unauthorized_response('Authentication failed')
        end
      end

      private

      ##
      # Check if request is exempt from authentication
      # @param request [Rack::Request] HTTP request
      # @return [Boolean] True if exempt
      def exempt_from_auth?(request)
        path = request.path_info
        method = request.request_method

        # Health endpoint is always exempt
        return true if path == '/api/health'

        # API info endpoint is exempt
        return true if path == '/api/v1' && method == 'GET'

        # Public read-only endpoints
        if method == 'GET'
          return true if path.match?(%r{^/api/v1/blueprints$})
          return true if path.match?(%r{^/api/v1/blueprints/\d+$})
          return true if path.match?(%r{^/api/v1/search$})
        end

        false
      end

      ##
      # Extract JWT token from request headers
      # @param request [Rack::Request] HTTP request
      # @return [String, nil] JWT token or nil
      def extract_token(request)
        # Check Authorization header
        auth_header = request.env['HTTP_AUTHORIZATION']
        return nil unless auth_header

        # Extract Bearer token
        match = auth_header.match(/^Bearer\s+(.+)$/i)
        match ? match[1] : nil
      end

      ##
      # Decode JWT token
      # @param token [String] JWT token
      # @return [Hash] Decoded payload
      # @raise [JWT::DecodeError] If token is invalid
      def decode_token(token)
        JWT.decode(token, @secret, true, {
                     algorithm: 'HS256',
                     verify_expiration: true,
                     verify_iat: true
                   }).first
      end

      ##
      # Generate unauthorized response
      # @param message [String] Error message
      # @return [Array] Rack response
      def unauthorized_response(message)
        [
          401,
          { 'Content-Type' => 'application/json' },
          [{
            error: message,
            code: 'UNAUTHORIZED',
            timestamp: Time.now.iso8601
          }.to_json]
        ]
      end
    end

    ##
    # Helper methods for generating JWT tokens (for testing/development)
    #
    class JWTHelper
      class << self
        ##
        # Generate JWT token for user
        # @param user_data [Hash] User information
        # @param secret [String] JWT secret
        # @param expires_in [Integer] Expiration time in seconds
        # @return [String] JWT token
        def generate_token(user_data, secret: nil, expires_in: 3600)
          secret ||= ENV.fetch('JWT_SECRET', 'your-secret-key-change-in-production')

          payload = {
            user: user_data,
            exp: Time.now.to_i + expires_in,
            iat: Time.now.to_i
          }

          JWT.encode(payload, secret, 'HS256')
        end

        ##
        # Generate development token for testing
        # @return [String] Test JWT token
        def development_token
          generate_token({
                           id: 'dev-user',
                           email: 'developer@blueprintscli.com',
                           role: 'developer'
                         }, expires_in: 86_400) # 24 hours
        end
      end
    end
  end
end
