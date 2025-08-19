# frozen_string_literal: true

require 'dotenv/load'
require 'sequel'
require 'redis'
require 'logger'
require 'json'

# Load environment-specific configuration
ENV['RACK_ENV'] ||= 'development'

# Configure database connection
DB = Sequel.connect(
  ENV.fetch('DATABASE_URL', 'postgres://localhost:5432/blueprintscli_development')
)

# Configure Redis connection
REDIS = Redis.new(
  url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'),
  reconnect_attempts: 3
)

# Configure logging
LOG_LEVEL = ENV.fetch('LOG_LEVEL', 'info').to_sym
LOGGER = Logger.new(STDOUT)
LOGGER.level = Logger.const_get(LOG_LEVEL.upcase)
LOGGER.formatter = proc do |severity, datetime, progname, msg|
  {
    timestamp: datetime.iso8601,
    level: severity,
    message: msg,
    service: 'blueprintscli-api',
    environment: ENV['RACK_ENV']
  }.to_json + "\n"
end

# JSON parser configured to use standard library