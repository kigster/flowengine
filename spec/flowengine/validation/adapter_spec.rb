# frozen_string_literal: true

RSpec.describe FlowEngine::Validation::Adapter do
  subject(:adapter) { described_class.new }

  describe "#validate" do
    it "raises NotImplementedError" do
      node = FlowEngine::Node.new(id: :test, type: :text, question: "Q")
      expect { adapter.validate(node, "input") }.to raise_error(NotImplementedError)
    end
  end
end

RSpec.describe FlowEngine::Validation::Result do
  describe "valid result" do
    subject(:result) { described_class.new(valid: true, errors: []) }

    it "is valid" do
      expect(result.valid?).to be true
    end

    it "has no errors" do
      expect(result.errors).to eq([])
    end

    it "is frozen" do
      expect(result).to be_frozen
    end

    it "has frozen errors" do
      expect(result.errors).to be_frozen
    end
  end

  describe "invalid result" do
    subject(:result) { described_class.new(valid: false, errors: ["field required"]) }

    it "is not valid" do
      expect(result.valid?).to be false
    end

    it "has errors" do
      expect(result.errors).to eq(["field required"])
    end
  end
end
