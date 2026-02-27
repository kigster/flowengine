# frozen_string_literal: true

require_relative "lib/flowengine/version"

Gem::Specification.new do |spec|
  spec.name = "flowengine"
  spec.version = FlowEngine::VERSION
  spec.authors = ["Konstantin Gredeskoul"]
  spec.email = ["kigster@gmail.com"]

  spec.summary = "A declarative flow engine for building rules-driven wizards and intake forms"
  spec.description = "FlowEngine provides a DSL for defining multi-step flows as directed graphs " \
                     "with conditional branching, an AST-based rule evaluator, and a pure-Ruby " \
                     "runtime engine. No framework dependencies."
  spec.homepage = "https://github.com/kigster/flowengine"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kigster/flowengine"
  spec.metadata["changelog_uri"] = "https://github.com/kigster/flowengine/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec-its", "~> 2.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
