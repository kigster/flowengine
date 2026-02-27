# frozen_string_literal: true

RSpec.describe FlowEngine::Rules::Contains do
  subject(:rule) { described_class.new(:earnings, "W2") }

  its(:field) { is_expected.to eq(:earnings) }
  its(:value) { is_expected.to eq("W2") }
  its(:to_s) { is_expected.to eq("W2 in earnings") }

  it "is frozen" do
    expect(rule).to be_frozen
  end

  describe "#evaluate" do
    it "returns true when array contains value" do
      expect(rule.evaluate({ earnings: %w[W2 1099] })).to be true
    end

    it "returns false when array does not contain value" do
      expect(rule.evaluate({ earnings: ["1099"] })).to be false
    end

    it "returns false when field is nil" do
      expect(rule.evaluate({})).to be false
    end

    it "wraps scalar in array for comparison" do
      expect(rule.evaluate({ earnings: "W2" })).to be true
    end

    it "returns false for empty array" do
      expect(rule.evaluate({ earnings: [] })).to be false
    end
  end
end
