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
    allow($stdin).to receive(:tty?).and_return(true)
    allow(DEBUGGER__::SESSION).to receive(:enter_postmortem_session)
  end

  describe "without a TTY" do
    before { allow($stdin).to receive(:tty?).and_return(false) }

    it "runs dit like it" do
      examples = run_group do
        dit
        dit("x") { raise "boom" }
      end

      expect(DEBUGGER__::SESSION).not_to have_received(:enter_postmortem_session)
      expect(examples.map { |ex| status(ex) }).to eq([:pending, :failed])
    end
  end

  describe "quitting the debugger" do
    it "fails the example and stops the run" do
      allow(DEBUGGER__::SESSION).to receive(:enter_postmortem_session).and_raise(SystemExit)

      failed, skipped = run_group do
        dit("x") { raise "boom" }
        it("y") {}
      end

      expect(status(failed)).to eq(:failed)
      expect(status(skipped)).to be_nil
    end

    it "doesn't reopen the debugger for an after hook failing in the same example" do
      allow(DEBUGGER__::SESSION).to receive(:enter_postmortem_session).and_raise(SystemExit)

      run_group do
        after { raise "after" }
        dit("x") { raise "boom" }
      end

      expect(DEBUGGER__::SESSION).to have_received(:enter_postmortem_session).once
    end

    it "stops the run from a blockless dit" do
      allow_any_instance_of(Object).to receive(:debugger).and_raise(SystemExit)

      _, skipped = run_group do
        dit
        it("y") {}
      end

      expect(status(skipped)).to be_nil
    end
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

    it "reports and prints the location where dit was written" do
      allow_any_instance_of(Object).to receive(:debugger)

      example, = run_group { dit }
      location = "#{RSpec::Core::Metadata.relative_path(__FILE__)}:#{__LINE__ - 1}"

      expect(example.location).to eq(location)
      expect($stderr.string).to include("debugging: #{location}")
    end

    it "reports the location inside shared examples" do
      allow_any_instance_of(Object).to receive(:debugger)

      example, = run_group do
        shared_examples("shared") { dit }
        it_behaves_like "shared"
      end

      expect(example.location).to eq("#{RSpec::Core::Metadata.relative_path(__FILE__)}:#{__LINE__ - 4}")
    end
  end

  it "leaves the location of a blockless it alone" do
    example, = run_group { it "todo" }

    expect(example.location).to eq("#{RSpec::Core::Metadata.relative_path(__FILE__)}:#{__LINE__ - 2}")
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

    it "lists the initialized lets by name" do
      run_group do
        let(:user) { "secret" }
        let(:account) { "secret" }
        let(:unused) { "secret" }
        dit("x") { user; account; raise "boom" }
      end

      expect($stderr.string).to include("initialized lets: user, account")
      expect($stderr.string).not_to include("unused")
      expect($stderr.string).not_to include("secret")
    end

    it "omits the lets line when none are initialized" do
      run_group { dit("x") { raise "boom" } }

      expect($stderr.string).not_to include("initialized lets")
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

  describe "not a failure" do
    it "leaves skip and pending examples alone" do
      examples = run_group do
        dit("skip") { skip "not today" }
        dit("pending") { pending "known bug"; expect(1).to eq(2) }
        dit("pending metadata", pending: "known bug") { expect(1).to eq(2) }
        context("skip in hook") { before { skip "not today" }; dit("x") {} }
      end

      expect(DEBUGGER__::SESSION).not_to have_received(:enter_postmortem_session)
      expect(examples.map { |ex| status(ex) }).to all(eq(:pending))
    end

    it "lets exit through" do
      expect { run_group { dit("x") { exit } } }.to raise_error(SystemExit)

      expect(DEBUGGER__::SESSION).not_to have_received(:enter_postmortem_session)
    end
  end

  describe "hooks" do
    it "opens the postmortem when a before hook, let! or after hook fails" do
      examples = run_group do
        context("before") { before { raise "before" }; dit("x") {} }
        context("let!") { let!(:user) { raise "let!" }; dit("x") {} }
        context("after") { after { raise "after" }; dit("x") {} }
      end

      expect(DEBUGGER__::SESSION).to have_received(:enter_postmortem_session).thrice
      expect(examples.map { |ex| status(ex) }).to all(eq(:failed))
    end

    it "opens the postmortem once when the example runs inside an around hook" do
      run_group do
        around { |ex| ex.run }
        dit("x") { raise "boom" }
      end

      expect(DEBUGGER__::SESSION).to have_received(:enter_postmortem_session).once
    end

    it "opens the postmortem once when the example calls instance_exec itself" do
      run_group { dit("x") { instance_exec { raise "boom" } } }

      expect(DEBUGGER__::SESSION).to have_received(:enter_postmortem_session).once
    end
  end

  it "reports the location where dit was written" do
    example, = run_group { dit("x") {} }

    expect(example.location).to eq("#{RSpec::Core::Metadata.relative_path(__FILE__)}:#{__LINE__ - 2}")
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
