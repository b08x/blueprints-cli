# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BlueprintsCLI::Actions::Submit do
  let(:valid_code) { "puts 'Hello, World!'" }
  let(:empty_code) { '' }
  let(:whitespace_code) { '   ' }

  # Mock the database
  let(:mock_db) { instance_double(BlueprintsCLI::BlueprintDatabase) }
  let(:mock_blueprint) do
    {
      id: 1,
      name: 'Test Blueprint',
      description: 'A test blueprint',
      code: valid_code,
      categories: [{ id: 1, title: 'Ruby' }],
      created_at: Time.now
    }
  end

  before do
    allow(BlueprintsCLI::BlueprintDatabase).to receive(:new).and_return(mock_db)
    allow(BlueprintsCLI.logger).to receive(:step)
    allow(BlueprintsCLI.logger).to receive(:success)
    allow(BlueprintsCLI.logger).to receive(:failure)
    allow(BlueprintsCLI.logger).to receive(:error)
    allow(BlueprintsCLI.logger).to receive(:info)
    allow(BlueprintsCLI.logger).to receive(:debug)
  end

  describe '#initialize' do
    it 'sets default values for optional parameters' do
      action = described_class.new(code: valid_code)

      expect(action.instance_variable_get(:@code)).to eq(valid_code)
      expect(action.instance_variable_get(:@name)).to be_nil
      expect(action.instance_variable_get(:@description)).to be_nil
      expect(action.instance_variable_get(:@categories)).to eq([])
      expect(action.instance_variable_get(:@auto_describe)).to be true
      expect(action.instance_variable_get(:@auto_categorize)).to be true
    end

    it 'accepts custom values for all parameters' do
      action = described_class.new(
        code: valid_code,
        name: 'Custom Name',
        description: 'Custom Description',
        categories: %w[Ruby Testing],
        auto_describe: false,
        auto_categorize: false
      )

      expect(action.instance_variable_get(:@name)).to eq('Custom Name')
      expect(action.instance_variable_get(:@description)).to eq('Custom Description')
      expect(action.instance_variable_get(:@categories)).to eq(%w[Ruby Testing])
      expect(action.instance_variable_get(:@auto_describe)).to be false
      expect(action.instance_variable_get(:@auto_categorize)).to be false
    end
  end

  describe '#call' do
    context 'with successful submission and all metadata provided' do
      it 'creates blueprint without auto-generation' do
        action = described_class.new(
          code: valid_code,
          name: 'Test Blueprint',
          description: 'A test blueprint',
          categories: ['Ruby'],
          auto_describe: false,
          auto_categorize: false
        )

        expect(mock_db).to receive(:create_blueprint).with(
          code: valid_code,
          name: 'Test Blueprint',
          description: 'A test blueprint',
          categories: ['Ruby']
        ).and_return(mock_blueprint)

        # Should not call any generators
        expect(BlueprintsCLI::Generators::Name).not_to receive(:new)
        expect(BlueprintsCLI::Generators::Description).not_to receive(:new)
        expect(BlueprintsCLI::Generators::Category).not_to receive(:new)

        result = action.call
        expect(result).to be true
      end
    end

    context 'with auto-generation enabled' do
      it 'generates missing name, description, and categories' do
        action = described_class.new(code: valid_code)

        # Mock generators
        mock_name_generator = instance_double(BlueprintsCLI::Generators::Name)
        mock_desc_generator = instance_double(BlueprintsCLI::Generators::Description)
        mock_cat_generator = instance_double(BlueprintsCLI::Generators::Category)

        allow(BlueprintsCLI::Generators::Name).to receive(:new).and_return(mock_name_generator)
        allow(BlueprintsCLI::Generators::Description).to receive(:new).and_return(mock_desc_generator)
        allow(BlueprintsCLI::Generators::Category).to receive(:new).and_return(mock_cat_generator)

        expect(mock_name_generator).to receive(:generate).and_return('Generated Name')
        expect(mock_desc_generator).to receive(:generate).and_return('Generated Description')
        expect(mock_cat_generator).to receive(:generate).and_return(%w[Generated Categories])

        expect(mock_db).to receive(:create_blueprint).with(
          code: valid_code,
          name: 'Generated Name',
          description: 'Generated Description',
          categories: %w[Generated Categories]
        ).and_return(mock_blueprint)

        result = action.call
        expect(result).to be true
      end
    end

    context 'with failed submission due to empty code' do
      it 'validates and rejects empty code' do
        action = described_class.new(code: empty_code)

        expect(mock_db).not_to receive(:create_blueprint)
        expect(BlueprintsCLI.logger).to receive(:failure).with('Validation errors:')
        expect(BlueprintsCLI.logger).to receive(:error).with('   - Code cannot be empty')

        result = action.call
        expect(result).to be false
      end

      it 'validates and rejects whitespace-only code' do
        action = described_class.new(code: whitespace_code)

        expect(mock_db).not_to receive(:create_blueprint)
        expect(BlueprintsCLI.logger).to receive(:failure).with('Validation errors:')
        expect(BlueprintsCLI.logger).to receive(:error).with('   - Code cannot be empty')

        result = action.call
        expect(result).to be false
      end
    end

    context 'when AI generation fails' do
      it 'handles name generation failure' do
        action = described_class.new(code: valid_code)

        mock_name_generator = instance_double(BlueprintsCLI::Generators::Name)
        allow(BlueprintsCLI::Generators::Name).to receive(:new).and_return(mock_name_generator)
        expect(mock_name_generator).to receive(:generate).and_return(nil)

        expect(mock_db).not_to receive(:create_blueprint)
        expect(BlueprintsCLI.logger).to receive(:failure).with('Validation errors:')
        expect(BlueprintsCLI.logger).to receive(:error).with('   - Name is required (auto-generation failed)')

        result = action.call
        expect(result).to be false
      end

      it 'handles description generation failure' do
        action = described_class.new(code: valid_code, name: 'Test Name')

        mock_desc_generator = instance_double(BlueprintsCLI::Generators::Description)
        allow(BlueprintsCLI::Generators::Description).to receive(:new).and_return(mock_desc_generator)
        expect(mock_desc_generator).to receive(:generate).and_return(nil)

        expect(mock_db).not_to receive(:create_blueprint)
        expect(BlueprintsCLI.logger).to receive(:failure).with('Validation errors:')
        expect(BlueprintsCLI.logger).to receive(:error).with('   - Description generation failed')

        result = action.call
        expect(result).to be false
      end
    end

    context 'when database creation fails' do
      it 'handles database creation failure gracefully' do
        action = described_class.new(
          code: valid_code,
          name: 'Test Blueprint',
          description: 'A test blueprint'
        )

        expect(mock_db).to receive(:create_blueprint).and_return(nil)
        expect(BlueprintsCLI.logger).to receive(:failure).with('Failed to create blueprint')

        result = action.call
        expect(result).to be false
      end
    end

    context 'when an exception occurs' do
      it 'handles exceptions gracefully' do
        action = described_class.new(code: valid_code, name: 'Test Blueprint')

        expect(mock_db).to receive(:create_blueprint).and_raise(StandardError, 'Database error')
        expect(BlueprintsCLI.logger).to receive(:failure).with('Error submitting blueprint: Database error')

        result = action.call
        expect(result).to be false
      end
    end
  end
end
