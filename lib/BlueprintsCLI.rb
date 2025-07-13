# frozen_string_literal: true

# This file is part of the blueprintsCLI gem, which provides a command-line interface
# for generating and managing code blueprints using Large Language Models (LLMs).

lib_dir = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift lib_dir unless $LOAD_PATH.include?(lib_dir)

require 'dotenv/load'

# Attempts to load the .env file, overwriting existing environment variables.
# If an error occurs, it displays an error message.
begin
  Dotenv.load('.env', overwrite: true)
rescue StandardError => e
  puts "Error loading .env file: #{e.message}"
end

require 'colorize'
require 'fileutils'
require 'git'
require 'json'
require 'net/http'
require 'open3'
require 'pg'
require 'sequel'
require 'sublayer'
require 'tempfile'
require 'terrapin'
require 'thor'
require 'time'
require 'tty-command'
require 'tty-config'
require 'tty-cursor'
require 'tty-file'
require 'tty-logger'
require 'tty-prompt'
require 'tty-table'
require 'tty-which'
require 'uri'
require 'yaml'

require_relative 'blueprintsCLI/version'
require_relative 'blueprintsCLI/configuration'
require_relative 'blueprintsCLI/logger'
require_relative 'blueprintsCLI/database'
require_relative 'blueprintsCLI/cli_ui_integration'
require_relative 'blueprintsCLI/slash_command_parser'
require_relative 'blueprintsCLI/enhanced_menu'
require_relative 'blueprintsCLI/simple_enhanced_menu'
require_relative 'blueprintsCLI/autocomplete_handler'

require_relative 'blueprintsCLI/providers/sublayer/ollama'
require_relative 'blueprintsCLI/providers/sublayer/openrouter'

Dir[File.join(__dir__, 'blueprintsCLI', 'commands', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'blueprintsCLI', 'generators', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'blueprintsCLI', 'actions', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'blueprintsCLI', 'agents', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'blueprintsCLI', 'ui', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'blueprintsCLI', 'setup', '*.rb')].each { |file| require file }

require_relative 'blueprintsCLI/cli'

module BlueprintsCLI
  class Error < StandardError; end

  # Global configuration instance using the new TTY::Config system
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Access to the legacy logger for backward compatibility
  def self.logger
    @logger ||= Logger.instance
  end

  def self.root
    File.dirname __dir__
  end
end
