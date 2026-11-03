# user code laid out like an RSpec extension: lib/rspec/...
module DebugItFixtures
  def self.extension_boom
    raise "boom"
  end
end
