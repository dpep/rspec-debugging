require "rspec/expectations"

require "rspec/debugging/debug_it"
require "rspec/debugging/let_variables"
require "rspec/debugging/version"

RSpec.configure do |config|
  config.include RSpec::Debugging::LetVariables
end
