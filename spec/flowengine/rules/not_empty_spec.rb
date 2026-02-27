# frozen_string_literal: true

RSpec.describe FlowEngine::Rules::NotEmpty do
  subject(:rule) { described_class.new(:name) }

  its(:field) { is_expected.to eq(:name) }
  its(:to_s) { is_expected.to eq("name is not empty") }

  it "is frozen" do
    expect(rule).to be_frozen
  end

  describe "#evaluate" do
    it "returns true when field has a non-empty string" do
      expect(rule.evaluate({ name: "John" })).to be true
    end

    it "returns false when field is nil" do
      expect(rule.evaluate({})).to be false
    end

    it "returns false when field is empty string" do
      expect(rule.evaluate({ name: "" })).to be false
    end

    it "returns false when field is empty array" do
      expect(rule.evaluate({ name: [] })).to be false
    end

    it "returns true when field is non-empty array" do
      expect(rule.evaluate({ name: ["a"] })).to be true
    end

    it "returns true for numeric values" do
      expect(rule.evaluate({ name: 0 })).to be true
    end

    it "returns false when field is explicitly nil" do
      expect(rule.evaluate({ name: nil })).to be false
    end
  end
end
