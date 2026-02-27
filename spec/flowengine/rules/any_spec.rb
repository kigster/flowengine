# frozen_string_literal: true

RSpec.describe FlowEngine::Rules::Any do
  let(:rule1) { FlowEngine::Rules::Contains.new(:earnings, "W2") }
  let(:rule2) { FlowEngine::Rules::Equals.new(:status, "Married") }

  subject(:rule) { described_class.new(rule1, rule2) }

  its(:rules) { is_expected.to eq([rule1, rule2]) }
  its(:to_s) { is_expected.to eq("(W2 in earnings OR status == Married)") }

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

    it "returns true when only first rule passes" do
      answers = { earnings: ["W2"], status: "Single" }
      expect(rule.evaluate(answers)).to be true
    end

    it "returns true when only second rule passes" do
      answers = { earnings: ["1099"], status: "Married" }
      expect(rule.evaluate(answers)).to be true
    end

    it "returns false when no rules pass" do
      answers = { earnings: ["1099"], status: "Single" }
      expect(rule.evaluate(answers)).to be false
    end

    it "returns false for empty rules list" do
      empty_any = described_class.new
      expect(empty_any.evaluate({})).to be false
    end
  end
end
