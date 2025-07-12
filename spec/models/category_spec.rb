# frozen_string_literal: true

# spec/models/category_spec.rb

require 'spec_helper'

RSpec.describe Category, type: :model do
  describe 'associations' do
    it 'has and belongs to many blueprints' do
      # Create a category and associate it with two blueprints
      category = create(:category)
      blueprint1 = create(:blueprint)
      blueprint2 = create(:blueprint)

      category.add_blueprint(blueprint1)
      category.add_blueprint(blueprint2)

      expect(category.blueprints.count).to eq(2)
      expect(category.blueprints.first).to be_a(Blueprint)
    end
  end

  describe 'validations' do
    it 'requires a unique name' do
      create(:category, name: 'Unique Name')
      duplicate_category = build(:category, name: 'Unique Name')
      expect { duplicate_category.save(validate: true) }.to raise_error(Sequel::UniqueConstraintViolation)
    end
  end
end
