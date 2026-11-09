require_relative "lib/rspec/debugging/version"

Gem::Specification.new do |s|
  s.authors     = ["Daniel Pepper"]
  s.description = "Tools to improve debugging in RSpec"
  s.files       = `git ls-files * ':!:spec'`.split("\n")
  s.homepage    = "https://github.com/dpep/rspec-debugging"
  s.license     = "MIT"
  s.name        = File.basename(__FILE__, ".gemspec")
  s.summary     = s.description
  s.version     = RSpec::Debugging::VERSION

  s.metadata = {
    "changelog_uri" => "#{s.homepage}/blob/main/CHANGELOG.md",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => s.homepage,
  }

  s.required_ruby_version = ">= 3.2"

  s.add_dependency "debug", ">= 1.10"
  s.add_dependency "rspec-core", ">= 3.10"

  s.add_development_dependency "rspec"
  s.add_development_dependency "simplecov", ">= 1"
end
