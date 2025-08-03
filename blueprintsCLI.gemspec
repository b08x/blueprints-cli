# frozen_string_literal: true

require_relative 'lib/blueprintsCLI/version'

Gem::Specification.new do |spec|
  spec.name = 'blueprintsCLI'
  spec.version = BlueprintsCLI::VERSION
  spec.authors = ['Robert Pannick']
  spec.email = ['rwpannick@gmail.com']

  spec.summary = 'AI-powered code blueprint management and generation system'
  spec.description = 'BlueprintsCLI is an intelligent code management tool that combines semantic search ' \
                     'with AI-powered code generation. Built on the Sublayer framework, it transforms ' \
                     'code snippets into searchable blueprints and generates new code using your ' \
                     'existing patterns as context.'
  spec.homepage = 'https://github.com/b08x/blueprints-cli'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/b08x/blueprints-cli'
  spec.metadata['changelog_uri'] = 'https://github.com/b08x/blueprints-cli/blob/master/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|github)|(?:appveyor|circle)\.yml)})
    end
  end
  spec.bindir = 'bin'
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Add dependencies here
  spec.add_dependency 'sublayer', '~> 0.2.9'
  spec.add_dependency 'thor', '~> 1.2'
end
