require_relative "lib/blueprintsCLI/version"

Gem::Specification.new do |spec|
  spec.name = "blueprintsCLI"
  spec.version = BlueprintsCLI::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "Summary of your project"
  spec.description = "Longer description of your project"
  spec.homepage = "https://github.com/yourusername/blueprintsCLI"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yourusername/blueprintsCLI"
  spec.metadata["changelog_uri"] = "https://github.com/yourusername/blueprintsCLI/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Add dependencies here
  spec.add_dependency "sublayer", "~> 0.2.9"
  spec.add_dependency "thor", "~> 1.2"
end
