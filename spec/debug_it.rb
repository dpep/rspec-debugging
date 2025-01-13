describe RSpec::Debugging do
  describe RSpec::Debugging::DebugIt do
    let(:a) { "a" }

    dit unless ENV['CI']

    # dit "it explodes and debugs" do
    #   # expect(DEBUGGER__::SESSION).to receive(:enter_postmortem_session)
    #   expect(a).to eq("az")
    # end

    # dcontext "when debugging" do
    #   it "explodes and debugs" do
    #     expect(a).to eq("az")
    #   end
    # end
  end
end
