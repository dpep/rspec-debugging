require "rspec/core/sandbox"

describe RSpec::Debugging::DebugIt do
  # Defines and runs a throwaway example group, isolated from this suite, and
  # returns its examples. Its examples don't use rspec-mocks, so our stubs here
  # stay intact.
  def run_group(dry_run: false, &block)
    RSpec::Core::Sandbox.sandboxed do |config|
      config.mock_with :nothing
      config.dry_run = dry_run
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
    allow($stderr).to receive(:tty?).and_return(true)
    allow($stdout).to receive(:tty?).and_return(true)
    allow(DEBUGGER__::SESSION).to receive(:enter_postmortem_session)
  end

  shared_examples "runs dit like it" do
    it "runs dit like it" do
      examples = run_group do
        dit
        dit("x") { raise "boom" }
      end

      expect(DEBUGGER__::SESSION).not_to have_received(:enter_postmortem_session)
      expect(examples.map { |ex| status(ex) }).to eq([:pending, :failed])
    end
  end

  describe "without a TTY" do
    before { allow($stdin).to receive(:tty?).and_return(false) }

    it_behaves_like "runs dit like it"
  end

  # e.g. rspec --bisect children: a TTY on stdin, but stderr captured
  describe "when stderr isn't a TTY" do
    before { allow($stderr).to receive(:tty?).and_return(false) }

    it_behaves_like "runs dit like it"
  end

  # e.g. rspec -f json > out.json: the debug console writes to stdout
  describe "when stdout isn't a TTY" do
    before { allow($stdout).to receive(:tty?).and_return(false) }

    it_behaves_like "runs dit like it"
  end

  describe "with a closed stdin" do
    # after the outer before, so the tty? stub stays on the real stdin
    before do
      @stdin = $stdin
      $stdin = IO.pipe.each(&:close).first
    end

    after { $stdin = @stdin }

    it "leaves plain examples alone" do
      examples = run_group do
        it("x") { expect(1).to eq(1) }
        it("y") { expect(1).to eq(1) }
      end

      expect(examples.map { |ex| status(ex) }).to eq([:passed, :passed])
    end

    it_behaves_like "runs dit like it"
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
    it "stays pending in a dry run" do
      example, = run_group(dry_run: true) { dit }

      expect(status(example)).to eq(:pending)
    end

    it "stays pending when it or its group is marked skip or pending" do
      expect_any_instance_of(Object).not_to receive(:debugger)

      examples = run_group do
        xdescribe("x") { dit }
        describe("skip", skip: "wip") { dit }
        describe("pending", pending: "later") { dit }
        dit("pending", pending: "later")
      end

      expect(examples.map { |ex| status(ex) }).to all(eq(:pending))
    end

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

      lets = $stderr.string[/^initialized lets: (.*)$/, 1].split(", ")
      expect(lets).to contain_exactly("user", "account")
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

    it "keeps the error from instance_exec in a thread, where there's no current example" do
      example, = run_group do
        dit("x") { Thread.new { instance_exec { raise "boom" } }.tap { |t| t.report_on_exception = false }.join }
      end

      expect(example.exception.message).to eq("boom")
    end
  end

  describe "postmortem frames" do
    require_relative "debug_it_fixtures/lib/rspec/extension"
    require_relative "debug_it_fixtures/lib/rspec-proj/code"

    def postmortem_paths(&body)
      error = nil
      allow(DEBUGGER__::SESSION).to receive(:enter_postmortem_session) { |e| error = e }

      run_group { dit("x", &body) }

      error.instance_variable_get(:@__debugger_postmortem_frames).map(&:path)
    end

    it "hides rspec and this gem, and shows the spec" do
      paths = postmortem_paths { raise "boom" }

      expect(paths).to include(__FILE__)
      expect(paths.grep(%r{/rspec-(core|expectations|mocks|support)\b})).to be_empty
      expect(paths.grep(/\A#{File.expand_path("../lib", __dir__)}\//)).to be_empty
    end

    it "shows user code under lib/rspec/" do
      paths = postmortem_paths { DebugItFixtures.extension_boom }

      expect(paths.first).to end_with("debug_it_fixtures/lib/rspec/extension.rb")
    end

    it "shows user code in a project under lib/rspec-*/" do
      paths = postmortem_paths { DebugItFixtures.project_boom }

      expect(paths.first).to end_with("debug_it_fixtures/lib/rspec-proj/code.rb")
    end
  end

  describe "the user's exceptions" do
    it "leaves rescued exceptions untouched, so they still marshal" do
      example, = run_group do
        dit("x") do
          error = (raise "rescued" rescue $!)
          raise "touched: #{error.instance_variables}" unless error.instance_variables.empty?
          Marshal.dump(error)
        end
      end

      expect(status(example)).to eq(:passed)
    end

    it "leaves the failure untouched, so it still marshals" do
      example, = run_group { dit("x") { raise "boom" } }

      expect(DEBUGGER__::SESSION).to have_received(:enter_postmortem_session)
      expect(example.exception.instance_variables).to be_empty
      expect { Marshal.dump(example.exception) }.not_to raise_error
    end

    it "copes with frozen exceptions" do
      frozen = RuntimeError.new("frozen boom").freeze

      passed, failed = run_group do
        dit("rescued") { expect { raise frozen }.to raise_error(frozen) }
        dit("failure") { raise frozen }
      end

      expect(status(passed)).to eq(:passed)
      expect(failed.exception).to equal(frozen)
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

    it "leaves blockless it placeholders inside them pending" do
      expect_any_instance_of(Object).not_to receive(:debugger)

      examples = run_group do
        ddescribe("d") { it "todo" }
        dcontext("c") { it "todo" }
      end

      expect(examples.map { |ex| status(ex) }).to all(eq(:pending))
    end

    it "leaves plain groups alone" do
      run_group { it("x") { raise "boom" } }

      expect(DEBUGGER__::SESSION).not_to have_received(:enter_postmortem_session)
    end
  end
end
