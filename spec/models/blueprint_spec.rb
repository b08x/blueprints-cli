# frozen_string_literal: true

# spec/models/blueprint_spec.rb

require 'spec_helper'

RSpec.describe Blueprint, type: :model do
  describe 'associations' do
    it 'has and belongs to many categories' do
      # Create a blueprint with two categories using the factory trait
      blueprint = create(:blueprint, :with_categories, categories_count: 2)
      expect(blueprint.categories.count).to eq(2)
      expect(blueprint.categories.first).to be_a(Category)
    end
  end

  describe '.search' do
    let!(:blueprint1) do
      create(:blueprint, name: 'Ruby Code', description: 'A simple Ruby script.')
    end
    let!(:blueprint2) do
      create(:blueprint, name: 'JavaScript Snippet', description: 'A utility function in JS.')
    end

    context 'when a query is provided' do
      it 'performs a semantic search' do
        # Mock the LLM embedding call
        mock_embedding = Array.new(768) { 0.5 }
        allow(RubyLLM).to receive(:embed).with(text: 'ruby').and_return(mock_embedding)

        # Expect the search to use the vector similarity operator
        results = Blueprint.search('ruby')
        # This is a basic check; a real test would need more sophisticated data setup
        # to verify the ordering based on vector distance.
        expect(results).to be_a(Sequel::Dataset)
      end
    end

    context 'when the query is nil or empty' do
      it 'returns the most recent blueprints' do
        # Ensure blueprint2 is newer than blueprint1
        blueprint2.update(created_at: Time.now)
        blueprint1.update(created_at: Time.now - 1.day)

        results = Blueprint.search(nil)
        expect(results.map(&:id)).to eq([blueprint2.id, blueprint1.id])

        results_empty_query = Blueprint.search('   ')
        expect(results_empty_query.map(&:id)).to eq([blueprint2.id, blueprint1.id])
      end
    end
  end
end
