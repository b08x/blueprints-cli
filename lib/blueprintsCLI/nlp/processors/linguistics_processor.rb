# frozen_string_literal: true

require_relative 'base_processor'

begin
  require 'linguistics'
  LINGUISTICS_AVAILABLE = true
rescue LoadError
  LINGUISTICS_AVAILABLE = false
  puts "Warning: linguistics gem not available. Linguistics processor will be disabled."
end

begin
  require 'rwordnet'
  require 'wordnet'
  WORDNET_AVAILABLE = true
rescue LoadError
  WORDNET_AVAILABLE = false
  puts "Warning: rwordnet gem not available. WordNet features will be disabled."
end

module BlueprintsCLI
  module NLP
    module Processors
      # Linguistics gem processor for morphological analysis and WordNet integration
      # Provides inflection, pluralization, stemming, and semantic relationships
      class LinguisticsProcessor < BaseProcessor
        include Linguistics if LINGUISTICS_AVAILABLE

        attr_reader :wordnet

        def initialize
          super
          
          if LINGUISTICS_AVAILABLE
            setup_linguistics
          else
            puts "Linguistics processor initialized in fallback mode"
          end
          
          if WORDNET_AVAILABLE
            begin
              @wordnet = WordNet::WordNetDB.instance
            rescue StandardError => e
              puts "Warning: Could not initialize WordNet: #{e.message}"
              @wordnet = nil
            end
          else
            @wordnet = nil
          end
          
          build_morphology_trie
        end

        # Main processing method using Linguistics and WordNet
        def process(text)
          start_time = Time.now

          begin
            # Check cache first
            cache_key = generate_cache_key(text)
            if cached_result = get_cached_result(cache_key)
              return cached_result
            end

            # Return fallback if libraries not available
            unless LINGUISTICS_AVAILABLE || WORDNET_AVAILABLE
              return fallback_processing(text)
            end

            # Tokenize and analyze
            words = tokenize_advanced(text)

            result = {
              morphology: analyze_morphology(words),
              inflections: analyze_inflections(words),
              semantic_relations: analyze_semantic_relations(words),
              word_forms: generate_word_forms(words),
              concepts: extract_concepts(words),
              sentiment_words: identify_sentiment_words(words),
              complexity_metrics: calculate_linguistic_complexity(words)
            }

            # Cache the result
            cache_result(cache_key, result, { text_length: text.length })

            duration = Time.now - start_time
            update_metrics(:linguistics_processing, duration, true)

            result
          rescue StandardError => e
            duration = Time.now - start_time
            update_metrics(:linguistics_processing, duration, false)

            # Return basic analysis on error
            {
              morphology: [],
              inflections: [],
              semantic_relations: [],
              word_forms: [],
              concepts: [],
              sentiment_words: [],
              complexity_metrics: {},
              error: e.message
            }
          end
        end

        # Analyze morphological features using Linguistics
        def analyze_morphology(words)
          morphology_data = []

          words.each do |word|
            next if word.length < 2

            morph_info = {
              word: word,
              singular: word.en.singular,
              plural: word.en.plural,
              stem: extract_stem(word),
              is_plural: word.en.plural?,
              ordinal: word.en.ordinal,
              cardinal: word.en.numwords
            }

            # Store in Red-Black tree for ordered morphological access
            @cache["morph_#{word}"] = morph_info
            morphology_data << morph_info

            # Add morphological variants to Trie
            @trie_index[morph_info[:singular].downcase] = word if morph_info[:singular]
            @trie_index[morph_info[:plural].downcase] = word if morph_info[:plural]
          end

          morphology_data
        end

        # Analyze inflectional patterns
        def analyze_inflections(words)
          inflections = []

          words.each do |word|
            next unless word.match?(/\A[a-zA-Z]+\z/) # Only alphabetic words

            inflection_data = {
              word: word,
              past_tense: generate_past_tense(word),
              present_participle: generate_present_participle(word),
              comparative: word.en.comparative,
              superlative: word.en.superlative,
              indefinite_article: word.en.a
            }

            inflections << inflection_data

            # Use priority queue to rank by inflectional complexity
            complexity_score = calculate_inflection_complexity(inflection_data)
            @priority_queue.push(inflection_data, complexity_score)
          end

          inflections
        end

        # Analyze semantic relationships using WordNet
        def analyze_semantic_relations(words)
          semantic_data = []

          words.each do |word|
            next if word.length < 3

            begin
              synsets = @wordnet.synsets(word)
              next if synsets.empty?

              primary_synset = synsets.first

              relations = {
                word: word,
                definition: primary_synset.definition,
                synonyms: extract_synonyms(synsets),
                hypernyms: extract_hypernyms(primary_synset),
                hyponyms: extract_hyponyms(primary_synset),
                meronyms: extract_meronyms(primary_synset),
                holonyms: extract_holonyms(primary_synset),
                antonyms: extract_antonyms(synsets),
                semantic_field: classify_semantic_field(primary_synset)
              }

              semantic_data << relations

              # Build semantic similarity vectors for KD-tree
              build_semantic_vectors(word, relations)
            rescue StandardError
              # Continue processing other words on error
              next
            end
          end

          semantic_data
        end

        # Generate various word forms using Linguistics
        def generate_word_forms(words)
          word_forms = {}

          words.each do |word|
            forms = {
              base: word,
              variations: {
                capitalized: word.capitalize,
                titlecase: word.en.titlecase,
                camelcase: word.gsub(/[^a-zA-Z0-9]/, '').en.camelcase,
                underscore: word.gsub(/\s+/, '_').downcase,
                hyphenated: word.gsub(/\s+/, '-').downcase
              },
              linguistic_forms: {
                singular: word.en.singular,
                plural: word.en.plural,
                possessive: "#{word}'s",
                gerund: generate_gerund(word)
              }
            }

            word_forms[word] = forms

            # Add all forms to Trie for fast lookup
            forms[:variations].each { |_type, form| @trie_index[form.downcase] = word }
            forms[:linguistic_forms].each do |_type, form|
              @trie_index[form.downcase] = word if form
            end
          end

          word_forms
        end

        # Extract semantic concepts using WordNet
        def extract_concepts(words)
          concepts = []
          concept_scores = {}

          words.each do |word|
            synsets = @wordnet.synsets(word)
            synsets.each do |synset|
              # Get semantic category
              category = get_lexical_category(synset)

              concept = {
                word: word,
                concept: synset.definition,
                category: category,
                hypernym_chain: build_hypernym_chain(synset),
                specificity: calculate_specificity(synset)
              }

              # Score concept by specificity and frequency
              score = concept[:specificity] * (1.0 / (synsets.length + 1))
              concept_scores[concept] = score

              concepts << concept
            end
          rescue StandardError
            next
          end

          # Use priority queue to rank concepts
          concept_scores.each { |concept, score| @priority_queue.push(concept, score) }

          # Extract top concepts
          top_concepts = []
          while !@priority_queue.empty? && top_concepts.length < 15
            top_concepts << @priority_queue.pop
          end

          top_concepts
        end

        # Identify sentiment-bearing words
        def identify_sentiment_words(words)
          sentiment_words = []

          words.each do |word|
            sentiment_info = analyze_word_sentiment(word)
            sentiment_words << sentiment_info if sentiment_info[:sentiment] != 'neutral'
          end

          sentiment_words.sort_by { |sw| -sw[:intensity] }
        end

        # Calculate linguistic complexity metrics
        def calculate_linguistic_complexity(words)
          {
            vocabulary_richness: calculate_vocabulary_richness(words),
            avg_word_length: words.map(&:length).sum.to_f / words.length,
            morphological_complexity: calculate_morphological_complexity(words),
            semantic_density: calculate_semantic_density(words),
            lexical_diversity: calculate_lexical_diversity(words)
          }
        end

        private

        def setup_linguistics
          # Enable English language processing
          Linguistics.use(:en) if LINGUISTICS_AVAILABLE
        end

        def fallback_processing(text)
          words = basic_tokenize(text)
          {
            morphology: [],
            inflections: [],
            semantic_relations: [],
            word_forms: {},
            concepts: [],
            sentiment_words: [],
            complexity_metrics: {
              vocabulary_richness: calculate_basic_richness(words),
              avg_word_length: words.map(&:length).sum.to_f / words.length,
              lexical_diversity: words.uniq.length.to_f / words.length
            },
            fallback: true
          }
        end

        def basic_tokenize(text)
          text.downcase.scan(/\b\w+\b/).select { |word| word.length > 2 }
        end

        def calculate_basic_richness(words)
          unique_words = words.uniq.length
          total_words = words.length
          return 0.0 if total_words == 0
          unique_words.to_f / total_words
        end

        def build_morphology_trie
          # Pre-populate with common morphological patterns
          morphological_patterns = {
            'running' => 'run',
            'better' => 'good',
            'best' => 'good',
            'children' => 'child',
            'mice' => 'mouse'
          }

          morphological_patterns.each { |inflected, base| @trie_index[inflected] = base }
        end

        def tokenize_advanced(text)
          # Enhanced tokenization preserving linguistic features
          words = text.downcase.scan(/\b[a-zA-Z]+\b/)
          words.select { |word| word.length > 2 }.uniq
        end

        def extract_stem(word)
          # Simple stemming algorithm - can be enhanced with Porter stemmer
          word.gsub(/ing$|ed$|s$|ly$/, '')
        end

        def generate_past_tense(word)
          # Basic past tense generation
          case word
          when /[^aeiou]y$/
            word.gsub(/y$/, 'ied')
          when /e$/
            word + 'd'
          when /[^aeiou][aeiou][^aeiou]$/
            word + word[-1] + 'ed'
          else
            word + 'ed'
          end
        end

        def generate_present_participle(word)
          # Basic present participle generation
          case word
          when /e$/
            word.gsub(/e$/, 'ing')
          when /[^aeiou][aeiou][^aeiou]$/
            word + word[-1] + 'ing'
          else
            word + 'ing'
          end
        end

        def generate_gerund(word)
          generate_present_participle(word)
        end

        def extract_synonyms(synsets)
          synonyms = []
          synsets.each do |synset|
            synset.words.each { |word| synonyms << word.lemma }
          end
          synonyms.uniq
        end

        def extract_hypernyms(synset)
          synset.hypernyms.map(&:words).flatten.map(&:lemma)
        end

        def extract_hyponyms(synset)
          synset.hyponyms.map(&:words).flatten.map(&:lemma)
        end

        def extract_meronyms(synset)
          (synset.part_meronyms + synset.member_meronyms + synset.substance_meronyms)
            .map(&:words).flatten.map(&:lemma)
        end

        def extract_holonyms(synset)
          (synset.part_holonyms + synset.member_holonyms + synset.substance_holonyms)
            .map(&:words).flatten.map(&:lemma)
        end

        def extract_antonyms(synsets)
          antonyms = []
          synsets.each do |synset|
            synset.words.each do |word|
              word.antonyms.each { |ant| antonyms << ant.lemma }
            end
          end
          antonyms.uniq
        end

        def classify_semantic_field(synset)
          # Basic semantic field classification
          lexfile = synset.lexical_file_name
          case lexfile
          when /noun\.person/
            'person'
          when /noun\.animal/
            'animal'
          when /noun\.plant/
            'plant'
          when /noun\.object/
            'object'
          when /verb\.motion/
            'motion'
          when /adj\.all/
            'quality'
          else
            'general'
          end
        end

        def build_semantic_vectors(word, relations)
          # Simple semantic vector based on relationship counts
          vector = [
            relations[:synonyms].length,
            relations[:hypernyms].length,
            relations[:hyponyms].length,
            relations[:meronyms].length
          ]

          @kd_tree_data[word] = vector if vector.any? { |v| v > 0 }
        end

        def get_lexical_category(synset)
          synset.pos
        end

        def build_hypernym_chain(synset, max_depth: 5)
          chain = []
          current = synset
          depth = 0

          while current.hypernyms.any? && depth < max_depth
            hypernym = current.hypernyms.first
            chain << hypernym.words.first.lemma
            current = hypernym
            depth += 1
          end

          chain
        end

        def calculate_specificity(synset)
          # Higher specificity = more hyponyms, fewer hypernyms
          hyponym_count = synset.hyponyms.length
          hypernym_count = synset.hypernyms.length

          return 0.5 if hyponym_count + hypernym_count == 0

          hyponym_count.to_f / (hyponym_count + hypernym_count + 1)
        end

        def analyze_word_sentiment(word)
          # Basic sentiment analysis using WordNet

          synsets = @wordnet.synsets(word)
          return { word: word, sentiment: 'neutral', intensity: 0.0 } if synsets.empty?

          # Simple sentiment scoring based on definition keywords
          definition = synsets.first.definition.downcase

          positive_indicators = %w[good great excellent positive beneficial
            pleasant]
          negative_indicators = %w[bad terrible negative harmful unpleasant
            difficult]

          pos_score = positive_indicators.count { |ind| definition.include?(ind) }
          neg_score = negative_indicators.count { |ind| definition.include?(ind) }

          if pos_score > neg_score
            { word: word, sentiment: 'positive', intensity: pos_score.to_f / 6.0 }
          elsif neg_score > pos_score
            { word: word, sentiment: 'negative', intensity: neg_score.to_f / 6.0 }
          else
            { word: word, sentiment: 'neutral', intensity: 0.0 }
          end
        rescue StandardError
          { word: word, sentiment: 'neutral', intensity: 0.0 }
        end

        def calculate_inflection_complexity(inflection_data)
          complexity = 0.0

          complexity += 0.2 if inflection_data[:past_tense] != inflection_data[:word]
          complexity += 0.2 if inflection_data[:comparative]
          complexity += 0.2 if inflection_data[:superlative]
          complexity += 0.1 if inflection_data[:present_participle]

          complexity
        end

        def calculate_vocabulary_richness(words)
          # Type-token ratio
          unique_words = words.uniq.length
          total_words = words.length
          return 0.0 if total_words == 0

          unique_words.to_f / total_words
        end

        def calculate_morphological_complexity(words)
          # Average morphological operations per word
          total_operations = words.sum do |word|
            operations = 0
            operations += 1 if word.en.plural?
            operations += 1 if word != word.en.singular
            operations
          end

          total_operations.to_f / words.length
        end

        def calculate_semantic_density(words)
          # Proportion of words with rich semantic relationships
          words_with_semantics = words.count do |word|
            synsets = @wordnet.synsets(word)
            synsets.any? && synsets.first.hypernyms.any?
          rescue StandardError
            false
          end

          words_with_semantics.to_f / words.length
        end

        def calculate_lexical_diversity(words)
          # Measure of lexical variation
          word_frequencies = words.tally
          max_frequency = word_frequencies.values.max
          return 0.0 if max_frequency == 0

          1.0 - (max_frequency.to_f / words.length)
        end

        def generate_cache_key(text)
          "linguistics_#{Digest::MD5.hexdigest(text[0..100])}"
        end
      end
    end
  end
end
