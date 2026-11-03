require "rspec/core/sandbox"

describe RSpec::Debugging::DebugIt do
  # Defines and runs a throwaway example group, isolated from this suite, and
  # returns its examples. Its examples don't use rspec-mocks, so our stubs here
  # stay intact.
  def run_group(&block)
    RSpec::Core::Sandbox.sandboxed do |config|
      config.mock_with :nothing
      config.include RSpec::Debugging::LetVariables

      group = RSpec.describe("sandbox", &block)
      group.run
      group.descendants.flat_map(&:examples)
    end
  end

  def status(example)
    example.execution_result.status
  end

  before do
    allow(DEBUGGER__::SESSION).to receive(:enter_postmortem_session)
  end

  around do |example|
    stderr = $stderr
    $stderr = StringIO.new
    example.run
  ensure
    $stderr = stderr
  end

  describe "blockless dit" do
    it "opens the debugger" do
      expect_any_instance_of(Object).to receive(:debugger)

      run_group { dit }

      expect($stderr.string).to include("debugging: ")
    end
  end

  describe "dit with a block" do
    it "opens the postmortem on a failed expectation, and still fails" do
      example, = run_group { dit("x") { expect("a").to eq("az") } }

      expect(DEBUGGER__::SESSION).to have_received(:enter_postmortem_session)
      expect($stderr.string).to include("Error:\n\nexpected: \"az\"")
      expect(status(example)).to eq(:failed)
    end

    it "opens the postmortem on a raised error" do
      example, = run_group { dit("x") { raise "boom" } }

      expect(DEBUGGER__::SESSION).to have_received(:enter_postmortem_session)
      expect(example.exception.message).to eq("boom")
    end

    it "passes the example to the block" do
      example, = run_group { dit("x") { |ex| raise "no example" unless ex.is_a?(RSpec::Core::Example) } }

      expect(status(example)).to eq(:passed)
    end

    it "stays out of the way when the example passes" do
      example, = run_group { dit("x") { expect(1).to eq(1) } }

      expect(DEBUGGER__::SESSION).not_to have_received(:enter_postmortem_session)
      expect(status(example)).to eq(:passed)
    end
  end

  describe "debug groups" do
    it "debugs examples inside ddescribe and dcontext" do
      run_group do
        ddescribe("d") { it("x") { raise "boom" } }
        dcontext("c") { context("nested") { it("y") { raise "boom" } } }
      end

      expect(DEBUGGER__::SESSION).to have_received(:enter_postmortem_session).twice
    end

    it "leaves plain groups alone" do
      run_group { it("x") { raise "boom" } }

      expect(DEBUGGER__::SESSION).not_to have_received(:enter_postmortem_session)
    end
  end
end
