require "byebug"
require "faker"
require "rspec"
require "rspec/matchers/fail_matchers"
require "simplecov"

SimpleCov.start do
  add_filter "spec/"
end

if ENV["CI"] == "true" || ENV["CODECOV_TOKEN"]
  require "codecov"
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

# load this gem
gem_name = Dir.glob("*.gemspec")[0].split(".")[0]
require gem_name

RSpec.configure do |config|
  # allow "fit" examples
  config.filter_run_when_matching :focus

  # expect { ... }.to fail
  config.include RSpec::Matchers::FailMatchers
end
