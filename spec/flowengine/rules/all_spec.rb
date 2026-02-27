# frozen_string_literal: true

RSpec.describe FlowEngine::Rules::All do
  let(:rule1) { FlowEngine::Rules::Contains.new(:earnings, "W2") }
  let(:rule2) { FlowEngine::Rules::Equals.new(:status, "Married") }

  subject(:rule) { described_class.new(rule1, rule2) }

  its(:rules) { is_expected.to eq([rule1, rule2]) }
  its(:to_s) { is_expected.to eq("(W2 in earnings AND status == Married)") }

  it "is frozen" do
    expect(rule).to be_frozen
  end

  it "has frozen rules array" do
    expect(rule.rules).to be_frozen
  end

  describe "#evaluate" do
    it "returns true when all rules pass" do
      answers = { earnings: ["W2"], status: "Married" }
      expect(rule.evaluate(answers)).to be true
    end

    it "returns false when first rule fails" do
      answers = { earnings: ["1099"], status: "Married" }
      expect(rule.evaluate(answers)).to be false
    end

    it "returns false when second rule fails" do
      answers = { earnings: ["W2"], status: "Single" }
      expect(rule.evaluate(answers)).to be false
    end

    it "returns false when all rules fail" do
      answers = { earnings: ["1099"], status: "Single" }
      expect(rule.evaluate(answers)).to be false
    end

    it "returns true for empty rules list" do
      empty_all = described_class.new
      expect(empty_all.evaluate({})).to be true
    end
  end
end
