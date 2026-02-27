# frozen_string_literal: true

RSpec.describe FlowEngine::Evaluator do
  let(:answers) { { earnings: %w[W2 BusinessOwnership], status: "Married" } }

  subject(:evaluator) { described_class.new(answers) }

  its(:answers) { is_expected.to eq(answers) }

  describe "#evaluate" do
    it "returns true when rule is nil" do
      expect(evaluator.evaluate(nil)).to be true
    end

    it "delegates to rule's evaluate method" do
      rule = FlowEngine::Rules::Contains.new(:earnings, "W2")
      expect(evaluator.evaluate(rule)).to be true
    end

    it "returns false when rule fails" do
      rule = FlowEngine::Rules::Contains.new(:earnings, "Rental")
      expect(evaluator.evaluate(rule)).to be false
    end

    it "works with composite rules" do
      rule = FlowEngine::Rules::All.new(
        FlowEngine::Rules::Contains.new(:earnings, "W2"),
        FlowEngine::Rules::Equals.new(:status, "Married")
      )
      expect(evaluator.evaluate(rule)).to be true
    end
  end
end
