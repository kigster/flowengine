# frozen_string_literal: true

RSpec.describe FlowEngine::Rules::GreaterThan do
  subject(:rule) { described_class.new(:income, 100_000) }

  its(:field) { is_expected.to eq(:income) }
  its(:value) { is_expected.to eq(100_000) }
  its(:to_s) { is_expected.to eq("income > 100000") }

  it "is frozen" do
    expect(rule).to be_frozen
  end

  describe "#evaluate" do
    it "returns true when field value is greater" do
      expect(rule.evaluate({ income: 150_000 })).to be true
    end

    it "returns false when field value is equal" do
      expect(rule.evaluate({ income: 100_000 })).to be false
    end

    it "returns false when field value is less" do
      expect(rule.evaluate({ income: 50_000 })).to be false
    end

    it "converts string values to integer" do
      expect(rule.evaluate({ income: "150000" })).to be true
    end

    it "treats nil as 0" do
      expect(rule.evaluate({})).to be false
    end
  end
end
