# frozen_string_literal: true

# spec/requests/app_spec.rb

require 'spec_helper'

RSpec.describe 'Blueprint API', type: :request do
  describe 'GET /blueprints' do
    let!(:blueprints) { create_list(:blueprint, 3) }

    it 'returns a list of blueprints' do
      get '/blueprints'
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Content-Type']).to eq('application/json')

      json_response = JSON.parse(last_response.body)
      expect(json_response.size).to eq(3)
      expect(json_response.first['name']).to eq(blueprints.last.name) # Default order is descending by created_at
    end

    it 'handles search queries' do
      # Mock the service layer to avoid LLM calls in request specs
      allow_any_instance_of(BlueprintService).to receive(:search).with('test').and_return([blueprints.first.to_hash])

      get '/blueprints?query=test'
      expect(last_response.status).to eq(200)

      json_response = JSON.parse(last_response.body)
      expect(json_response.size).to eq(1)
      expect(json_response.first['name']).to eq(blueprints.first.name)
    end
  end

  describe 'POST /blueprints' do
    let(:blueprint_params) do
      {
        name: 'API Blueprint',
        description: 'Created via API.',
        code: 'def api_method; end',
        categories: %w[API Test]
      }
    end

    it 'creates a new blueprint' do
      # Mock the service layer to isolate the request spec
      allow_any_instance_of(BlueprintService).to receive(:create).and_return(blueprint_params.merge(id: 1))

      post '/blueprints', blueprint_params.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(201)
      json_response = JSON.parse(last_response.body)
      expect(json_response['name']).to eq('API Blueprint')
      expect(json_response['id']).to eq(1)
    end

    it 'returns a 400 for invalid JSON' do
      post '/blueprints', '{"name": "bad json"', { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
      json_response = JSON.parse(last_response.body)
      expect(json_response['error']).to eq('Invalid JSON')
    end
  end

  describe 'CORS preflight requests' do
    it 'handles OPTIONS requests to /blueprints' do
      options '/blueprints'
      expect(last_response.status).to eq(200)
      expect(last_response.headers['Access-Control-Allow-Origin']).to eq('*')
      expect(last_response.headers['Access-Control-Allow-Methods']).to include('POST')
    end
  end
end
