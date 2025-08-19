# frozen_string_literal: true

require 'rack'
require 'rack/cors'
require_relative 'lib/api'

# Enable CORS for all routes
use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: %i[get post put delete options]
  end
end

# Run the API
run BlueprintsCLI::API.new
