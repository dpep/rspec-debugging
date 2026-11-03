describe RSpec::Debugging do
  describe RSpec::Debugging::LetVariables do
    subject { let_variable_get(:a) }

    let!(:a) { "a" }
    let(:b) { "b" }
    let(:c) { "c" }
    let(:letters) { [a, b, c] }

    it { expect(letters).to eq(["a", "b", "c"]) }

    it { expect(self).to respond_to(:let_variables) }

    it "does not mix in private helpers" do
      helpers = (methods + private_methods).grep(/normalize_path|let_variable_methods/)
      expect(helpers).to be_empty
    end

    context "when the user defines a helper with the same name" do
      def normalize_path(_path) = "USER"

      it "does not use the user's helper" do
        expect(let_variable_locations(:a)).to all(start_with("spec/"))
      end
    end

    it "returns the defined let variables" do
      expect(let_variables).to include(:a, :b, :c, :letters)
    end

    it { is_expected.to eq "a" }

    context "in A upper case land" do
      let!(:a) { "A" }

      it { expect(letters).to eq(["A", "b", "c"]) }

      describe "let_variable_get" do
        it { expect(let_variable_get(:a)).to eq "A" }

        it { expect(let_variable_locations(:a).count).to be 2 }
      end

      context "when B is doubled" do
        let!(:a) { "AA" }
        let(:b) { "BB" }

        it { expect(letters).to eq(["AA", "BB", "c"]) }

        it { is_expected.to eq "AA" }

        it "tracks where the variable is declared" do
          expect(let_variable_locations(:a).count).to be 3
        end

        it "returns the values of a let variable at different scopes" do
          expect(
            let_variable_values(:a).map(&:values).flatten
          ).to eq(["AA", "A", "a"])
        end
      end
    end

    describe "let_variable_values" do
      it "does not initialize the lets a definition references" do
        expect(let_variable_values(:letters).first.values).to eq([["a", "b", "c"]])

        expect(let_variable_initialized?(:a)).to be true
        expect(let_variable_initialized?(:b)).to be false
        expect(let_variable_initialized?(:letters)).to be false
      end

      context "when a definition raises" do
        let(:b) { raise "boom" }

        it "returns the error for that definition only" do
          inner, outer = let_variable_values(:b).flat_map(&:values)

          expect(inner).to be_a(RuntimeError).and have_attributes(message: "boom")
          expect(outer).to eq "b"
        end
      end

      context "when a definition takes the example" do
        let(:description) { |example| example.description }

        it "passes it the current example" do
          expect(let_variable_values(:description).flat_map(&:values)).to eq([description])
        end
      end

      context "when definitions call super" do
        let(:c) { super() + "!" }

        context "twice" do
          let(:c) { super() + "?" }

          it "ignores the memoized value" do
            expect(c).to eq "c!?"
            expect(let_variable_values(:c).flat_map(&:values)).to eq(["c!?", "c!", "c"])
            expect(let_variable_get(:c)).to eq "c!?"
          end
        end
      end
    end

    describe "names" do
      it "accepts strings" do
        expect(let_variable_initialized?("a")).to be true
        expect(let_variable_get("a")).to eq "a"
        expect(let_variable_locations("a").count).to be 1
        expect(let_variable_values("a")).to eq(let_variable_values(:a))
      end

      it "raises on an unknown name" do
        %i[let_variable_initialized? let_variable_get let_variable_reset let_variable_locations let_variable_values].each do |helper|
          expect { send(helper, :nope) }.to raise_error(ArgumentError, /nope/)
        end
      end

      context "with a named subject" do
        subject(:thing) { "thing" }

        it "treats subject as the named let" do
          expect(let_variable_values(:subject)).to eq(let_variable_values(:thing))
          expect(let_variable_initialized?(:subject)).to be false

          subject

          expect(let_variable_get(:subject)).to eq "thing"
        end
      end
    end

    describe "let_variable_initialized?" do
      it "tracks whether a let variable has been initialized" do
        expect(let_variable_initialized?(:c)).to be false

        expect(c).to eq("c")

        expect(let_variable_initialized?(:c)).to be true
      end
    end

    describe "let_variable_reset" do
      let(:time) { Time.now.to_f }

      it "resets a let variable" do
        t = time

        expect(let_variable_initialized?(:time)).to be true
        expect(time).to eq t

        let_variable_reset(:time)

        expect(let_variable_initialized?(:time)).to be false
        expect(time).to be > t
      end
    end

    context "in a before(:context) hook" do
      results = nil

      before(:context) do
        results = {
          initialized: let_variable_initialized?(:a),
          get: let_variable_get(:a),
          reset: let_variable_reset(:a),
          values: let_variable_values(:a).flat_map(&:values),
        }
      end

      it "treats every let as uninitialized" do
        expect(results).to eq(initialized: false, get: nil, reset: nil, values: ["a"])
      end
    end
  end
end

# a described class whose name contains "LetDefinitions" isn't a let module
LetDefinitionsLookalike = Class.new

describe LetDefinitionsLookalike do
  let(:a) { "a" }

  it "only lists let variables" do
    expect(let_variables).to eq [:a]
  end
end
