describe RSpec::Debugging do
  describe RSpec::Debugging::LetVariables do
    subject { let_variable_get(:a) }

    let!(:a) { "a" }
    let(:b) { "b" }
    let(:c) { "c" }
    let(:letters) { [a, b, c] }

    it { expect(letters).to eq(["a", "b", "c"]) }

    it { expect(self).to respond_to(:let_variables) }

    it "does not expose helpers" do
      expect(methods).not_to include(:normalize_path)
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
  end
end
