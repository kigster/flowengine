# frozen_string_literal: true

RSpec.describe FlowEngine::Rules::LessThan do
  subject(:rule) { described_class.new(:age, 18) }

  its(:field) { is_expected.to eq(:age) }
  its(:value) { is_expected.to eq(18) }
  its(:to_s) { is_expected.to eq("age < 18") }

  it "is frozen" do
    expect(rule).to be_frozen
  end

  describe "#evaluate" do
    it "returns true when field value is less" do
      expect(rule.evaluate({ age: 15 })).to be true
    end

    it "returns false when field value is equal" do
      expect(rule.evaluate({ age: 18 })).to be false
    end

    it "returns false when field value is greater" do
      expect(rule.evaluate({ age: 25 })).to be false
    end

    it "converts string values to integer" do
      expect(rule.evaluate({ age: "10" })).to be true
    end

    it "treats nil as 0" do
      expect(rule.evaluate({})).to be true
    end
  end
end
