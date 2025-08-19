# frozen_string_literal: true

require 'securerandom'

module BlueprintsCLI
  module Middleware
    ##
    # Redis-based rate limiting middleware
    # Implements token bucket algorithm for API rate limiting
    #
    class RateLimiter
      # Default rate limiting configuration
      DEFAULT_CONFIG = {
        requests_per_minute: ENV.fetch('RATE_LIMIT_RPM', 60).to_i,
        burst_limit: ENV.fetch('RATE_LIMIT_BURST', 10).to_i,
        window_size: 60, # seconds
        key_prefix: 'blueprintscli:rate_limit'
      }.freeze

      ##
      # Initialize rate limiter middleware
      # @param app [Object] Rack application
      # @param config [Hash] Rate limiting configuration
      def initialize(app, config = {})
        @app = app
        @config = DEFAULT_CONFIG.merge(config)
        @redis = REDIS
        @logger = LOGGER
      end

      ##
      # Process request with rate limiting
      # @param env [Hash] Rack environment
      # @return [Array] Rack response
      def call(env)
        request = Rack::Request.new(env)

        # Skip rate limiting for health checks
        return @app.call(env) if skip_rate_limiting?(request)

        # Get client identifier
        client_key = get_client_key(request)

        # Check rate limit
        if rate_limited?(client_key)
          @logger.warn "Rate limit exceeded for client: #{client_key}"
          return rate_limit_response(client_key)
        end

        # Record request
        record_request(client_key)

        # Add rate limit headers to response
        status, headers, body = @app.call(env)
        add_rate_limit_headers(headers, client_key)

        [status, headers, body]
      end

      private

      ##
      # Check if request should skip rate limiting
      # @param request [Rack::Request] HTTP request
      # @return [Boolean] True if should skip
      def skip_rate_limiting?(request)
        # Skip health check endpoints
        request.path_info == '/api/health'
      end

      ##
      # Get client key for rate limiting
      # @param request [Rack::Request] HTTP request
      # @return [String] Client identifier
      def get_client_key(request)
        # Use API key if present
        api_key = request.env['HTTP_X_API_KEY']
        return "api_key:#{api_key}" if api_key

        # Use authenticated user ID if available
        user_id = request.env['current_user']&.dig('id')
        return "user:#{user_id}" if user_id

        # Fall back to IP address
        ip = get_client_ip(request)
        "ip:#{ip}"
      end

      ##
      # Get client IP address
      # @param request [Rack::Request] HTTP request
      # @return [String] Client IP
      def get_client_ip(request)
        # Check X-Forwarded-For header (load balancer/proxy)
        forwarded_for = request.env['HTTP_X_FORWARDED_FOR']
        if forwarded_for
          # Take the first IP (original client)
          return forwarded_for.split(',').first.strip
        end

        # Check X-Real-IP header (nginx)
        real_ip = request.env['HTTP_X_REAL_IP']
        return real_ip if real_ip

        # Fall back to REMOTE_ADDR
        request.env['REMOTE_ADDR'] || 'unknown'
      end

      ##
      # Check if client is rate limited
      # @param client_key [String] Client identifier
      # @return [Boolean] True if rate limited
      def rate_limited?(client_key)
        redis_key = "#{@config[:key_prefix]}:#{client_key}"
        current_time = Time.now.to_i
        window_start = current_time - @config[:window_size]

        # Clean old entries and count current requests
        @redis.multi do |multi|
          multi.zremrangebyscore(redis_key, 0, window_start)
          multi.zcard(redis_key)
          multi.expire(redis_key, @config[:window_size] * 2)
        end

        results = @redis.exec
        current_count = results[1] || 0

        # Check if limit exceeded
        current_count >= @config[:requests_per_minute]
      end

      ##
      # Record request in rate limit store
      # @param client_key [String] Client identifier
      def record_request(client_key)
        redis_key = "#{@config[:key_prefix]}:#{client_key}"
        current_time = Time.now.to_f

        # Add current request with score as timestamp
        @redis.zadd(redis_key, current_time, "#{current_time}:#{SecureRandom.hex(8)}")
        @redis.expire(redis_key, @config[:window_size] * 2)
      end

      ##
      # Add rate limit headers to response
      # @param headers [Hash] Response headers
      # @param client_key [String] Client identifier
      def add_rate_limit_headers(headers, client_key)
        redis_key = "#{@config[:key_prefix]}:#{client_key}"
        current_time = Time.now.to_i
        window_start = current_time - @config[:window_size]

        # Get current usage
        current_count = @redis.zcount(redis_key, window_start, '+inf')
        remaining = [@config[:requests_per_minute] - current_count, 0].max

        # Calculate reset time
        oldest_request = @redis.zrange(redis_key, 0, 0, with_scores: true).first
        reset_time = if oldest_request
                       oldest_request[1].to_i + @config[:window_size]
                     else
                       current_time + @config[:window_size]
                     end

        headers.merge!(
          'X-RateLimit-Limit' => @config[:requests_per_minute].to_s,
          'X-RateLimit-Remaining' => remaining.to_s,
          'X-RateLimit-Reset' => reset_time.to_s,
          'X-RateLimit-Window' => @config[:window_size].to_s
        )
      end

      ##
      # Generate rate limit exceeded response
      # @param client_key [String] Client identifier
      # @return [Array] Rack response
      def rate_limit_response(client_key)
        # Calculate when limit resets
        redis_key = "#{@config[:key_prefix]}:#{client_key}"
        current_time = Time.now.to_i
        @config[:window_size]

        oldest_request = @redis.zrange(redis_key, 0, 0, with_scores: true).first
        reset_time = if oldest_request
                       oldest_request[1].to_i + @config[:window_size]
                     else
                       current_time + @config[:window_size]
                     end

        headers = {
          'Content-Type' => 'application/json',
          'X-RateLimit-Limit' => @config[:requests_per_minute].to_s,
          'X-RateLimit-Remaining' => '0',
          'X-RateLimit-Reset' => reset_time.to_s,
          'X-RateLimit-Window' => @config[:window_size].to_s,
          'Retry-After' => (reset_time - current_time).to_s
        }

        body = {
          error: 'Rate limit exceeded',
          code: 'RATE_LIMIT_EXCEEDED',
          message: "Too many requests. Limit: #{@config[:requests_per_minute]} requests per minute.",
          retry_after: reset_time - current_time,
          timestamp: Time.now.iso8601
        }.to_json

        [429, headers, [body]]
      end
    end
  end
end
