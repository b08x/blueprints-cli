# frozen_string_literal: true

# spec/services/blueprint_service_spec.rb

require 'spec_helper'
require_relative '../../app/services/blueprint_service'

RSpec.describe BlueprintService do
  let(:service) { BlueprintService.new }

  describe '#search' do
    it 'calls Blueprint.search and returns the results' do
      # Create some test data
      create_list(:blueprint, 3)

      # Test search without a query
      results = service.search(nil)
      expect(results.count).to eq(3)
      expect(results.first).to include(:name, :description, :code)
    end
  end

  describe '#create' do
    let(:valid_params) do
      {
        'name' => 'New Service Blueprint',
        'description' => 'A test service.',
        'code' => 'class TestService; end',
        'categories' => %w[Ruby Service]
      }
    end
    let(:mock_embedding) { Array.new(768) { 0.1 } }

    before do
      # Mock the LLM call to avoid actual API requests
      allow(RubyLLM).to receive(:embed).and_return(mock_embedding)
    end

    it 'creates a new blueprint with the given parameters' do
      expect { service.create(valid_params) }.to change(Blueprint, :count).by(1)
    end

    it 'assigns an embedding to the new blueprint' do
      blueprint_hash = service.create(valid_params)
      blueprint = Blueprint[blueprint_hash[:id]]
      expect(blueprint.embedding).to eq(Pgvector.encode(mock_embedding))
      expect(RubyLLM).to have_received(:embed).with(text: "#{valid_params['name']} #{valid_params['description']}")
    end

    it 'creates and associates categories' do
      expect { service.create(valid_params) }.to change(Category, :count).by(2)
      blueprint_hash = service.create(valid_params)
      blueprint = Blueprint[blueprint_hash[:id]]
      expect(blueprint.categories.map(&:name)).to match_array(%w[Ruby Service])
    end

    it 'reuses existing categories' do
      existing_category = create(:category, name: 'Ruby')
      expect { service.create(valid_params) }.to change(Category, :count).by(1) # Only "Service" is new
      blueprint_hash = service.create(valid_params)
      blueprint = Blueprint[blueprint_hash[:id]]
      expect(blueprint.categories.count).to eq(2)
    end
  end
end
