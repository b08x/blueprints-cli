# frozen_string_literal: true

module BlueprintsCLI
  module Utils
    # Utility class for detecting programming languages from code content
    class LanguageDetector
      # Common file extensions mapped to language identifiers
      EXTENSION_PATTERNS = {
        python: /\A\s*(?:#.*\n)*\s*(?:def |class |import |from |print\(|if __name__|@\w+)/m,
        ruby: /\A\s*(?:#.*\n)*\s*(?:class |module |def |require |puts |p |print |gem |bundle|end\s*$|\@\w+\s*=)/m,
        javascript: /\A\s*(?:\/\/.*\n|\/\*[\s\S]*?\*\/)*\s*(?:function|const|let|var|=>|console\.|document\.|window\.)/m,
        java: /\A\s*(?:\/\/.*\n|\/\*[\s\S]*?\*\/)*\s*(?:public|private|protected|class|interface|import|package)/m,
        php: /\A\s*<\?php/m,
        shell: /\A\s*#!.*\/(?:bash|sh|zsh)/m,
        go: /\A\s*(?:\/\/.*\n)*\s*(?:package |import |func |var |type |const )/m,
        rust: /\A\s*(?:\/\/.*\n)*\s*(?:fn |let |use |mod |pub |struct |enum |impl )/m,
        cpp: /\A\s*(?:\/\/.*\n|\/\*[\s\S]*?\*\/)*\s*(?:#include|using namespace|int main|class |template)/m,
        c: /\A\s*(?:\/\/.*\n|\/\*[\s\S]*?\*\/)*\s*(?:#include|int main|void |struct |typedef)/m,
        sql: /\A\s*(?:--.*\n)*\s*(?:SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER)/im,
        yaml: /\A\s*(?:#.*\n)*\s*(?:[a-zA-Z][a-zA-Z0-9_]*\s*:|---|\.\.\.|version\s*:)/m,
        json: /\A\s*[{\[]/m,
        html: /\A\s*(?:<!DOCTYPE|<html|<head|<body|<div|<span|<p|<script|<style)/im,
        css: /\A\s*(?:\/\*[\s\S]*?\*\/)*\s*(?:[.#]?[a-zA-Z][a-zA-Z0-9_-]*\s*\{|@media|@import)/m,
        xml: /\A\s*<\?xml|<[a-zA-Z][a-zA-Z0-9_-]*[^>]*>/m
      }.freeze

      # Additional content-based patterns for better detection
      KEYWORD_PATTERNS = {
        ruby: %w[require gem bundle def class module end puts p],
        python: %w[def class import from print __name__ __main__],
        javascript: %w[function const let var console document window],
        java: %w[public private protected class interface import package],
        php: %w[<?php echo $_ $_GET $_POST function],
        shell: %w[#!/bin/bash #!/bin/sh echo printf read if],
        go: %w[package import func var type const],
        rust: %w[fn let use mod pub struct enum impl],
        cpp: %w[#include using namespace template class],
        c: %w[#include stdio.h stdlib.h int main void],
        sql: %w[SELECT INSERT UPDATE DELETE CREATE DROP ALTER],
        yaml: %w[version name description dependencies],
        html: %w[<!DOCTYPE <html <head <body <div <span],
        css: %w[color background margin padding font],
        xml: %w[<?xml version encoding]
      }.freeze

      class << self
        # Detect the programming language of the given code
        # @param code [String] The code content to analyze
        # @return [String] The detected language identifier
        def detect(code)
          return 'text' if code.nil? || code.strip.empty?

          normalized_code = code.strip.downcase

          # First try pattern matching
          EXTENSION_PATTERNS.each do |language, pattern|
            return language.to_s if code.match?(pattern)
          end

          # Fallback to keyword scoring
          detect_by_keywords(normalized_code)
        end

        private

        # Detect language by counting keyword matches
        # @param normalized_code [String] The normalized code content
        # @return [String] The detected language identifier
        def detect_by_keywords(normalized_code)
          scores = {}

          KEYWORD_PATTERNS.each do |language, keywords|
            score = keywords.sum { |keyword| normalized_code.scan(keyword.downcase).size }
            scores[language] = score if score > 0
          end

          # Return the language with the highest score, or 'text' if no matches
          return 'text' if scores.empty?

          scores.max_by { |_, score| score }.first.to_s
        end
      end
    end
  end
end