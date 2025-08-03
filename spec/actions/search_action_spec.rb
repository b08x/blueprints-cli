# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BlueprintsCLI::Actions::Search do
  let(:search_query) { 'ruby http server' }
  let(:mock_db) { instance_double(BlueprintsCLI::BlueprintDatabase) }
  let(:mock_blueprints) do
    [
      {
        id: 1,
        name: 'HTTP Server',
        description: 'A simple Ruby HTTP server',
        code: "require 'webrick'\nserver = WEBrick::HTTPServer.new",
        categories: [{ id: 1, title: 'Ruby' }, { id: 2, title: 'Web' }],
        distance: 0.15
      },
      {
        id: 2,
        name: 'TCP Server',
        description: 'Ruby TCP socket server',
        code: "require 'socket'\nserver = TCPServer.open(2000)",
        categories: [{ id: 1, title: 'Ruby' }, { id: 3, title: 'Network' }],
        distance: 0.25
      }
    ]
  end

  before do
    allow(BlueprintsCLI::BlueprintDatabase).to receive(:new).and_return(mock_db)
    allow(BlueprintsCLI.logger).to receive(:failure)
    allow(BlueprintsCLI.logger).to receive(:debug)
  end

  describe '#initialize' do
    it 'sets default values for optional parameters' do
      action = described_class.new(query: search_query)

      expect(action.instance_variable_get(:@query)).to eq(search_query)
      expect(action.instance_variable_get(:@limit)).to eq(10)
      expect(action.instance_variable_get(:@semantic)).to be true
    end

    it 'accepts custom values for all parameters' do
      action = described_class.new(
        query: search_query,
        limit: 5,
        semantic: false
      )

      expect(action.instance_variable_get(:@query)).to eq(search_query)
      expect(action.instance_variable_get(:@limit)).to eq(5)
      expect(action.instance_variable_get(:@semantic)).to be false
    end
  end

  describe '#call' do
    context 'with semantic search enabled' do
      it 'performs semantic search and displays results' do
        action = described_class.new(query: search_query, semantic: true)

        expect(mock_db).to receive(:search_blueprints).with(
          query: search_query,
          limit: 10
        ).and_return(mock_blueprints)

        # Capture output
        expect { action.call }.to output(/🔍 Searching for: 'ruby http server'/).to_stdout
        expect { action.call }.to output(/✅ Found 2 matching blueprints/).to_stdout

        result = action.call
        expect(result).to be true
      end

      it 'handles no results found' do
        action = described_class.new(query: search_query, semantic: true)

        expect(mock_db).to receive(:search_blueprints).with(
          query: search_query,
          limit: 10
        ).and_return([])

        expect do
          action.call
        end.to output(/📭 No blueprints found matching 'ruby http server'/).to_stdout

        result = action.call
        expect(result).to be true
      end
    end

    context 'with text search' do
      let(:all_blueprints) do
        [
          {
            id: 1,
            name: 'HTTP Server',
            description: 'A simple Ruby HTTP server',
            code: "require 'webrick'\nserver = WEBrick::HTTPServer.new",
            categories: [{ title: 'Ruby' }, { title: 'Web' }]
          },
          {
            id: 2,
            name: 'Database Connection',
            description: 'PostgreSQL connection helper',
            code: "require 'pg'\nconnection = PG.connect",
            categories: [{ title: 'Ruby' }, { title: 'Database' }]
          },
          {
            id: 3,
            name: 'HTTP Client',
            description: 'Making HTTP requests in Ruby',
            code: "require 'net/http'\nuri = URI('http://example.com')",
            categories: [{ title: 'Ruby' }, { title: 'HTTP' }]
          }
        ]
      end

      it 'performs text search and returns relevant results' do
        action = described_class.new(query: 'http', semantic: false, limit: 5)

        expect(mock_db).to receive(:list_blueprints).with(limit: 1000).and_return(all_blueprints)

        # Should find blueprints 1 and 3 (contain 'http')
        expect { action.call }.to output(/🔍 Searching for: 'http'/).to_stdout
        expect { action.call }.to output(/✅ Found 2 matching blueprints/).to_stdout

        result = action.call
        expect(result).to be true
      end

      it 'handles case-insensitive search' do
        action = described_class.new(query: 'HTTP', semantic: false)

        expect(mock_db).to receive(:list_blueprints).with(limit: 1000).and_return(all_blueprints)

        # Should still find results despite case differences
        result = action.call
        expect(result).to be true
      end

      it 'searches across multiple fields' do
        action = described_class.new(query: 'database', semantic: false)

        expect(mock_db).to receive(:list_blueprints).with(limit: 1000).and_return(all_blueprints)

        # Should find blueprint 2 (contains 'database' in category and description)
        result = action.call
        expect(result).to be true
      end

      it 'requires all query words to be present' do
        action = described_class.new(query: 'ruby database missing', semantic: false)

        expect(mock_db).to receive(:list_blueprints).with(limit: 1000).and_return(all_blueprints)

        # Should find no results since 'missing' is not in any blueprint
        expect do
          action.call
        end.to output(/📭 No blueprints found matching 'ruby database missing'/).to_stdout

        result = action.call
        expect(result).to be true
      end

      it 'respects the limit parameter' do
        action = described_class.new(query: 'ruby', semantic: false, limit: 1)

        # All blueprints contain 'ruby'
        expect(mock_db).to receive(:list_blueprints).with(limit: 1000).and_return(all_blueprints)

        # Should return only 1 result due to limit
        expect { action.call }.to output(/✅ Found 1 matching blueprints/).to_stdout

        result = action.call
        expect(result).to be true
      end
    end

    context 'when an exception occurs' do
      it 'handles exceptions gracefully in semantic search' do
        action = described_class.new(query: search_query, semantic: true)

        expect(mock_db).to receive(:search_blueprints).and_raise(StandardError, 'Search error')
        expect(BlueprintsCLI.logger).to receive(:failure).with('Error searching blueprints: Search error')

        result = action.call
        expect(result).to be false
      end

      it 'handles exceptions gracefully in text search' do
        action = described_class.new(query: search_query, semantic: false)

        expect(mock_db).to receive(:list_blueprints).and_raise(StandardError, 'Database error')
        expect(BlueprintsCLI.logger).to receive(:failure).with('Error searching blueprints: Database error')

        result = action.call
        expect(result).to be false
      end
    end
  end

  describe 'private methods' do
    let(:action) { described_class.new(query: search_query) }

    describe '#calculate_text_relevance' do
      let(:blueprint) do
        {
          name: 'HTTP Server',
          description: 'A ruby HTTP server',
          code: 'puts "hello"'
        }
      end

      it 'calculates relevance scores correctly' do
        # Name match: 10 points, description match: 5 points
        score = action.send(:calculate_text_relevance, blueprint, ['http'])
        expect(score).to eq(15) # 10 (name) + 5 (description)
      end

      it 'gives higher weight to name matches' do
        score = action.send(:calculate_text_relevance, blueprint, ['server'])
        expect(score).to eq(15) # 10 (name) + 5 (description)
      end

      it 'counts code matches with lower weight' do
        score = action.send(:calculate_text_relevance, blueprint, ['hello'])
        expect(score).to eq(1) # 1 (code)
      end

      it 'handles multiple word matches' do
        score = action.send(:calculate_text_relevance, blueprint, %w[http ruby])
        expect(score).to eq(20) # 15 (http) + 5 (ruby in description)
      end
    end

    describe '#calculate_similarity_percentage' do
      it 'converts distance to percentage' do
        # Lower distance = higher similarity
        percentage = action.send(:calculate_similarity_percentage, 0.1)
        expect(percentage).to eq(90.0)
      end

      it 'handles zero distance' do
        percentage = action.send(:calculate_similarity_percentage, 0.0)
        expect(percentage).to eq(100.0)
      end

      it 'handles high distance' do
        percentage = action.send(:calculate_similarity_percentage, 1.5)
        expect(percentage).to eq(0.0) # Clamped to 0
      end
    end

    describe '#get_category_text' do
      it 'formats categories correctly' do
        categories = [{ title: 'Ruby' }, { title: 'Web' }]
        result = action.send(:get_category_text, categories)
        expect(result).to eq('Ruby, Web')
      end

      it 'handles empty categories' do
        result = action.send(:get_category_text, [])
        expect(result).to eq('None')
      end

      it 'handles nil categories' do
        result = action.send(:get_category_text, nil)
        expect(result).to eq('None')
      end

      it 'truncates long category text' do
        long_categories = [
          { title: 'Very Long Category Name' },
          { title: 'Another Very Long Category Name' }
        ]
        result = action.send(:get_category_text, long_categories)
        expect(result.length).to be <= 23
        expect(result).to end_with('...')
      end
    end

    describe '#truncate_text' do
      it 'returns original text if within length' do
        result = action.send(:truncate_text, 'short', 10)
        expect(result).to eq('short')
      end

      it 'truncates and adds ellipsis if too long' do
        result = action.send(:truncate_text, 'this is a very long text', 10)
        expect(result).to eq('this i...')
        expect(result.length).to eq(10)
      end
    end
  end
end
