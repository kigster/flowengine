# frozen_string_literal: true

RSpec.describe FlowEngine::Rules::Equals do
  subject(:rule) { described_class.new(:status, "Married") }

  its(:field) { is_expected.to eq(:status) }
  its(:value) { is_expected.to eq("Married") }
  its(:to_s) { is_expected.to eq("status == Married") }

  it "is frozen" do
    expect(rule).to be_frozen
  end

  describe "#evaluate" do
    it "returns true when values match" do
      expect(rule.evaluate({ status: "Married" })).to be true
    end

    it "returns false when values differ" do
      expect(rule.evaluate({ status: "Single" })).to be false
    end

    it "returns false when field is missing" do
      expect(rule.evaluate({})).to be false
    end

    it "returns false when field is nil" do
      expect(rule.evaluate({ status: nil })).to be false
    end

    it "uses strict equality" do
      numeric_rule = described_class.new(:count, 5)
      expect(numeric_rule.evaluate({ count: 5 })).to be true
      expect(numeric_rule.evaluate({ count: "5" })).to be false
    end
  end
end
