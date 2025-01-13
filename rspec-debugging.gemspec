Gem::Specification.new do |s|
  s.authors     = ["Daniel Pepper"]
  s.description = "Tools to improve debugging in RSpec"
  s.files       = `git ls-files * ':!:spec'`.split("\n")
  s.homepage    = "https://github.com/dpep/rspec-debugging"
  s.license     = "MIT"
  s.name        = File.basename(__FILE__, ".gemspec")
  s.summary     = s.description
  s.version     = "0.0.2"

  s.required_ruby_version = ">= 3.1"

  s.add_dependency "rspec-expectations", ">= 3"

  s.add_development_dependency "debug"
  s.add_development_dependency "rspec"
  s.add_development_dependency "simplecov"
end
