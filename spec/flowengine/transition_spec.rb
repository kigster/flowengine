# frozen_string_literal: true

RSpec.describe FlowEngine::Transition do
  describe "unconditional transition" do
    subject(:transition) { described_class.new(target: :next_step) }

    its(:target) { is_expected.to eq(:next_step) }
    its(:rule) { is_expected.to be_nil }
    its(:condition_label) { is_expected.to eq("always") }

    it "is frozen" do
      expect(transition).to be_frozen
    end

    describe "#applies?" do
      it "always returns true" do
        expect(transition.applies?({})).to be true
        expect(transition.applies?({ anything: "value" })).to be true
      end
    end
  end

  describe "conditional transition" do
    let(:rule) { FlowEngine::Rules::Contains.new(:earnings, "W2") }

    subject(:transition) { described_class.new(target: :w2_details, rule: rule) }

    its(:target) { is_expected.to eq(:w2_details) }
    its(:rule) { is_expected.to eq(rule) }
    its(:condition_label) { is_expected.to eq("W2 in earnings") }

    describe "#applies?" do
      it "returns true when rule passes" do
        expect(transition.applies?({ earnings: ["W2"] })).to be true
      end

      it "returns false when rule fails" do
        expect(transition.applies?({ earnings: ["1099"] })).to be false
      end
    end
  end
end
