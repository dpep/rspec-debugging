RUN_COUNT = 0

describe RSpec::Debugging do
  describe RSpec::Debugging::DebugIt do
    let(:a) { "a" }

    # dit

    # dit "it explodes and debugs" do
    #   expect(DEBUGGER__::SESSION).to receive(:enter_postmortem_session)
    #   expect(a).to eq("az")
    # end

    # dcontext "when debugging" do
    #   it "explodes and debugs" do
    #     expect(a).to eq("az")
    #   end
    # end

    context do
      before do
        expect_any_instance_of(Object).to receive(:debugger)
      end

      around do |ex|
        stderr = $stderr
        $stderr = StringIO.new

        ex.run

        raise $stderr.string unless $stderr.string.include?("debugging")
      ensure
        $stderr = stderr
      end

      dit
    end

    context do
      around do |ex|
        stderr = $stderr
        $stderr = StringIO.new

        ex.run

        raise $stderr.string unless $stderr.string.include?("Error:\n\nexpected:")

        if ex.exception.is_a?(RSpec::Expectations::ExpectationNotMetError)
          ex.example.instance_variable_set(:@exception, nil)
        end
      ensure
        $stderr = stderr
      end

      dit "it fails and debugs" do
        expect(DEBUGGER__::SESSION).to receive(:enter_postmortem_session)
        expect(a).to eq("az")
      end
    end

    context do
      let(:error) { RuntimeError.new("debugging") }

      after do |ex|
        if ex.display_exception == error
          ex.display_exception = nil
        end
      end

      dit "it explodes and debugs" do
        expect(DEBUGGER__::SESSION).to receive(:enter_postmortem_session)

        raise error
      end
    end
  end
end
