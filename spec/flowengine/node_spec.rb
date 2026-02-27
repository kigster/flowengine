# frozen_string_literal: true

RSpec.describe FlowEngine::Node do
  describe "basic node" do
    subject(:node) do
      described_class.new(
        id: :earnings,
        type: :multi_select,
        question: "What are your main earnings?",
        options: %w[W2 1099 BusinessOwnership]
      )
    end

    its(:id) { is_expected.to eq(:earnings) }
    its(:type) { is_expected.to eq(:multi_select) }
    its(:question) { is_expected.to eq("What are your main earnings?") }
    its(:options) { is_expected.to eq(%w[W2 1099 BusinessOwnership]) }
    its(:fields) { is_expected.to be_nil }
    its(:transitions) { is_expected.to eq([]) }
    its(:visibility_rule) { is_expected.to be_nil }

    it "is frozen" do
      expect(node).to be_frozen
    end

    it "has frozen options" do
      expect(node.options).to be_frozen
    end

    it "has frozen transitions" do
      expect(node.transitions).to be_frozen
    end
  end

  describe "node with fields" do
    subject(:node) do
      described_class.new(
        id: :business_details,
        type: :number_matrix,
        question: "How many business types?",
        fields: %w[RealEstate SCorp CCorp]
      )
    end

    its(:fields) { is_expected.to eq(%w[RealEstate SCorp CCorp]) }

    it "has frozen fields" do
      expect(node.fields).to be_frozen
    end
  end

  describe "#next_step_id" do
    let(:rule) { FlowEngine::Rules::Contains.new(:earnings, "BusinessOwnership") }
    let(:transition) { FlowEngine::Transition.new(target: :business_details, rule: rule) }

    subject(:node) do
      described_class.new(
        id: :earnings,
        type: :multi_select,
        question: "Earnings?",
        transitions: [transition]
      )
    end

    it "returns target when transition applies" do
      expect(node.next_step_id({ earnings: ["BusinessOwnership"] })).to eq(:business_details)
    end

    it "returns nil when no transitions apply" do
      expect(node.next_step_id({ earnings: ["W2"] })).to be_nil
    end

    it "returns nil when no transitions exist" do
      empty_node = described_class.new(id: :end, type: :text, question: "Done")
      expect(empty_node.next_step_id({})).to be_nil
    end

    context "with multiple transitions" do
      let(:rule2) { FlowEngine::Rules::Contains.new(:earnings, "W2") }
      let(:transition2) { FlowEngine::Transition.new(target: :w2_details, rule: rule2) }

      subject(:node) do
        described_class.new(
          id: :earnings,
          type: :multi_select,
          question: "Earnings?",
          transitions: [transition, transition2]
        )
      end

      it "returns first matching transition's target" do
        answers = { earnings: %w[BusinessOwnership W2] }
        expect(node.next_step_id(answers)).to eq(:business_details)
      end

      it "skips non-matching transitions" do
        answers = { earnings: ["W2"] }
        expect(node.next_step_id(answers)).to eq(:w2_details)
      end
    end
  end

  describe "#visible?" do
    it "returns true when no visibility rule" do
      node = described_class.new(id: :test, type: :text, question: "Q")
      expect(node.visible?({})).to be true
    end

    it "returns true when visibility rule passes" do
      rule = FlowEngine::Rules::Contains.new(:earnings, "W2")
      node = described_class.new(id: :test, type: :text, question: "Q", visibility_rule: rule)
      expect(node.visible?({ earnings: ["W2"] })).to be true
    end

    it "returns false when visibility rule fails" do
      rule = FlowEngine::Rules::Contains.new(:earnings, "W2")
      node = described_class.new(id: :test, type: :text, question: "Q", visibility_rule: rule)
      expect(node.visible?({ earnings: ["1099"] })).to be false
    end
  end
end
