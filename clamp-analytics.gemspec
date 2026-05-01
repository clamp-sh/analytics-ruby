# frozen_string_literal: true

require_relative "lib/clamp_analytics/version"

Gem::Specification.new do |spec|
  spec.name = "clamp-analytics"
  spec.version = Clamp::Analytics::VERSION
  spec.authors = ["Clamp Analytics"]
  spec.email = ["sidney@mail.clamp.sh"]

  spec.summary = "Server-side analytics SDK for Clamp."
  spec.description = "Send tracked events from Ruby apps (Rails, Sinatra, Sidekiq, etc.) to Clamp Analytics."
  spec.homepage = "https://clamp.sh"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/clamp-sh/analytics-ruby"
  spec.metadata["documentation_uri"] = "https://clamp.sh/docs/sdk/ruby"
  spec.metadata["bug_tracker_uri"] = "https://github.com/clamp-sh/analytics-ruby/issues"
  spec.metadata["changelog_uri"] = "https://github.com/clamp-sh/analytics-ruby/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("lib/**/*.rb") + ["README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "webmock", "~> 3.20"
end
