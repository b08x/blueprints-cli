# frozen_string_literal: true

# This file is part of the blueprintsCLI gem, which provides a command-line interface
# for generating and managing code blueprints using Large Language Models (LLMs).

lib_dir = File.expand_path(File.join(__dir__, '..', 'lib'))
$LOAD_PATH.unshift lib_dir unless $LOAD_PATH.include?(lib_dir)

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
require 'tty-file'
require 'tty-logger'
require 'tty-prompt'
require 'tty-table'
require 'tty-which'
require 'uri'
require 'yaml'

require_relative 'blueprintsCLI/version'
require_relative 'blueprintsCLI/config'

Dir[File.join(__dir__, 'blueprintsCLI', 'commands', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'blueprintsCLI', 'generators', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'blueprintsCLI', 'actions', '*.rb')].each { |file| require file }
Dir[File.join(__dir__, 'blueprintsCLI', 'agents', '*.rb')].each { |file| require file }

require_relative 'blueprintsCLI/cli'

module BlueprintsCLI
  class Error < StandardError; end
  Config.load

  def self.root
    File.dirname __dir__
  end
end
