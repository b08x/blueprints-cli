# frozen_string_literal: true

require_relative 'base_processor'
require 'spacy'

module BlueprintsCLI
  module NLP
    module Processors
      # SpaCy-powered NLP processor for advanced linguistic analysis
      # Provides POS tagging, NER, dependency parsing, and sentence segmentation
      class SpacyProcessor < BaseProcessor
        attr_reader :nlp_model, :model_name

        def initialize(model_name: 'en_core_web_sm')
          super()
          @model_name = model_name
          @nlp_model = load_spacy_model
          build_linguistic_trie
        end

        # Main processing method using SpaCy pipeline
        def process(text)
          start_time = Time.now

          begin
            # Check cache first
            cache_key = generate_cache_key(text)
            if cached_result = get_cached_result(cache_key)
              return cached_result
            end

            # Process with SpaCy
            doc = @nlp_model.call(text)

            result = {
              tokens: extract_tokens(doc),
              entities: extract_entities(doc),
              pos_tags: extract_pos_tags(doc),
              dependencies: extract_dependencies(doc),
              sentences: extract_sentences(doc),
              noun_phrases: extract_noun_phrases(doc),
              keywords: extract_spacy_keywords(doc)
            }

            # Cache the result
            cache_result(cache_key, result, { model: @model_name, text_length: text.length })

            duration = Time.now - start_time
            update_metrics(:spacy_processing, duration, true)

            result
          rescue StandardError => e
            duration = Time.now - start_time
            update_metrics(:spacy_processing, duration, false)

            # Return basic analysis on error
            {
              tokens: tokenize(text),
              entities: [],
              pos_tags: [],
              dependencies: [],
              sentences: [text],
              noun_phrases: [],
              keywords: [],
              error: e.message
            }
          end
        end

        # Extract named entities with confidence scores
        def extract_entities(doc)
          entities = []

          doc.ents.each do |entity|
            entity_data = {
              text: entity.text,
              label: entity.label_,
              start: entity.start_char,
              end: entity.end_char,
              confidence: entity._.get('confidence') || 0.8 # Default confidence
            }

            # Add to priority queue for ranking
            @priority_queue.push(entity_data, entity_data[:confidence])
            entities << entity_data

            # Index in Trie for fast lookup
            @trie_index[entity.text.downcase] = entity.label_
          end

          entities.sort_by { |e| -e[:confidence] }
        end

        # Extract POS tags with linguistic features
        def extract_pos_tags(doc)
          pos_data = []

          doc.each do |token|
            next if token.is_space || token.is_punct

            pos_info = {
              text: token.text,
              lemma: token.lemma_,
              pos: token.pos_,
              tag: token.tag_,
              is_alpha: token.is_alpha,
              is_stop: token.is_stop,
              shape: token.shape_,
              dependency: token.dep_
            }

            pos_data << pos_info

            # Store in Red-Black tree for ordered access by position
            @cache["pos_#{token.i}"] = pos_info
          end

          pos_data
        end

        # Extract syntactic dependencies
        def extract_dependencies(doc)
          dependencies = []

          doc.each do |token|
            next if token.head == token # Skip root

            dep_info = {
              token: token.text,
              head: token.head.text,
              relation: token.dep_,
              children: token.children.map(&:text)
            }

            dependencies << dep_info
          end

          dependencies
        end

        # Extract noun phrases for concept identification
        def extract_noun_phrases(doc)
          noun_phrases = []

          doc.noun_chunks.each do |chunk|
            phrase_info = {
              text: chunk.text,
              root: chunk.root.text,
              root_pos: chunk.root.pos_,
              start: chunk.start,
              end: chunk.end
            }

            noun_phrases << phrase_info

            # Add to Trie for phrase lookup
            @trie_index[chunk.text.downcase] = chunk.root.text
          end

          noun_phrases
        end

        # Extract keywords using SpaCy's linguistic features
        def extract_spacy_keywords(doc)
          keywords = []

          # Score tokens based on linguistic features
          doc.each do |token|
            next if token.is_stop || token.is_punct || token.is_space
            next if token.text.length < 3

            score = calculate_spacy_score(token)

            next unless score > 0.3 # Threshold for keyword inclusion

            keyword = {
              text: token.text,
              lemma: token.lemma_,
              pos: token.pos_,
              score: score
            }

            keywords << keyword
            @priority_queue.push(keyword, score)
          end

          # Return top keywords using priority queue
          top_keywords = []
          while !@priority_queue.empty? && top_keywords.length < 20
            top_keywords << @priority_queue.pop
          end

          top_keywords
        end

        # Analyze text structure and complexity
        def analyze_text_structure(text)
          doc = @nlp_model.call(text)

          {
            sentence_count: doc.sents.count,
            token_count: doc.length,
            avg_sentence_length: doc.length.to_f / doc.sents.count,
            complexity_score: calculate_complexity_score(doc),
            readability: estimate_readability(doc)
          }
        end

        private

        def load_spacy_model
          Spacy::Language.new(@model_name)
        rescue StandardError
          # Fallback to basic English model
          puts "Warning: Could not load #{@model_name}, falling back to basic model"
          Spacy::Language.new('en_core_web_sm')
        end

        def build_linguistic_trie
          # Pre-populate Trie with common linguistic patterns
          common_patterns = {
            'artificial intelligence' => 'AI_CONCEPT',
            'machine learning' => 'ML_CONCEPT',
            'natural language processing' => 'NLP_CONCEPT',
            'deep learning' => 'DL_CONCEPT',
            'neural network' => 'NN_CONCEPT'
          }

          common_patterns.each { |pattern, label| @trie_index[pattern] = label }
        end

        def extract_tokens(doc)
          tokens = []

          doc.each do |token|
            next if token.is_space

            tokens << {
              text: token.text,
              lemma: token.lemma_,
              pos: token.pos_,
              is_alpha: token.is_alpha,
              is_stop: token.is_stop
            }
          end

          tokens
        end

        def extract_sentences(doc)
          doc.sents.map(&:text)
        end

        def calculate_spacy_score(token)
          score = 0.0

          # Base score from token properties
          score += 0.3 if token.is_alpha
          score += 0.2 if token.pos_ == 'NOUN'
          score += 0.15 if token.pos_ == 'VERB'
          score += 0.1 if token.pos_ == 'ADJ'
          score += 0.4 if token.ent_type_ != '' # Is part of named entity
          score -= 0.2 if token.is_stop

          # Length bonus
          score += [token.text.length.to_f / 10.0, 0.3].min

          # Frequency penalty (more common = lower score)
          score -= token.prob * 0.1 if token.prob

          score.clamp(0.0, 1.0)
        end

        def calculate_complexity_score(doc)
          # Simple complexity based on sentence structure
          avg_deps_per_token = doc.map { |token| token.children.count }.sum.to_f / doc.length
          avg_deps_per_token / 3.0 # Normalize
        end

        def estimate_readability(doc)
          # Simple readability estimate
          avg_word_length = doc.select(&:is_alpha).map { |t| t.text.length }.sum.to_f /
                            doc.select(&:is_alpha).count

          case avg_word_length
          when 0..4 then 'easy'
          when 4..6 then 'medium'
          else 'hard'
          end
        end

        def generate_cache_key(text)
          "spacy_#{@model_name}_#{Digest::MD5.hexdigest(text[0..100])}"
        end
      end
    end
  end
end
