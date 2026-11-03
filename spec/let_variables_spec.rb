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
  end
end
