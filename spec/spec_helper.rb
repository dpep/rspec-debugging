require "debug"
require "rspec"
require "rspec/matchers/fail_matchers"
require "simplecov"

SimpleCov.start do
  add_filter "/spec/"
end

if ENV["CI"] == "true" || ENV["CODECOV_TOKEN"]
  require "simplecov_json_formatter"
  SimpleCov.formatter = SimpleCov::Formatter::JSONFormatter
end

# load this gem
require Dir.glob("*.gemspec")[0].split(".")[0]

RSpec.configure do |config|
  # allow "fit" examples
  # config.filter_run_when_matching :focus

  # expect { ... }.to fail
  config.include RSpec::Matchers::FailMatchers
end
