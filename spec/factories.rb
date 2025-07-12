# frozen_string_literal: true

require 'factory_bot'
require 'pgvector'

FactoryBot.define do
  # Factory for the Category model
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
  end

  # Factory for the Blueprint model
  factory :blueprint do
    sequence(:name) { |n| "Blueprint Name #{n}" }
    sequence(:description) { |n| "This is the description for blueprint #{n}." }
    sequence(:code) { |n| "puts 'Hello World #{n}'" }

    # Generate a random embedding for testing purposes
    embedding { Pgvector.encode(Array.new(768) { rand(-1.0..1.0) }) }

    # Trait to create a blueprint with associated categories
    trait :with_categories do
      transient do
        categories_count { 2 }
      end

      after(:create) do |blueprint, evaluator|
        create_list(:category, evaluator.categories_count).each do |category|
          blueprint.add_category(category)
        end
      end
    end
  end
end
