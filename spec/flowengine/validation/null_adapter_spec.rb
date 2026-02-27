# frozen_string_literal: true

RSpec.describe FlowEngine::Validation::NullAdapter do
  subject(:adapter) { described_class.new }

  describe "#validate" do
    it "always returns a valid result" do
      node = FlowEngine::Node.new(id: :test, type: :text, question: "Q")
      result = adapter.validate(node, "anything")

      expect(result.valid?).to be true
      expect(result.errors).to eq([])
    end
  end
end
