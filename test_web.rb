# frozen_string_literal: true

require 'sinatra'

# Simple web server
get '/' do
  'Hello, World! This is a simple Sinatra web server.'
end

get '/api/users' do
  content_type :json
  {
    users: [
      { id: 1, name: 'Alice', email: 'alice@example.com' },
      { id: 2, name: 'Bob', email: 'bob@example.com' }
    ]
  }.to_json
end

get '/api/users/:id' do
  user_id = params[:id].to_i
  user = {
    id: user_id,
    name: "User #{user_id}",
    email: "user#{user_id}@example.com"
  }

  content_type :json
  user.to_json
end
