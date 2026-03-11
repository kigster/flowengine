# frozen_string_literal: true

RSpec.describe FlowEngine::DSL::StepBuilder do
  subject(:builder) { described_class.new }

  describe "#build" do
    it "creates a Node with all attributes" do
      builder.type :multi_select
      builder.question "Pick earnings"
      builder.options %w[W2 1099]
      builder.transition to: :next_step, if_rule: builder.contains(:earnings, "W2")
      builder.visible_if builder.equals(:status, "Active")

      node = builder.build(:earnings)

      expect(node).to be_a(FlowEngine::Node)
      expect(node.id).to eq(:earnings)
      expect(node.type).to eq(:multi_select)
      expect(node.question).to eq("Pick earnings")
      expect(node.options).to eq(%w[W2 1099])
      expect(node.transitions.length).to eq(1)
      expect(node.transitions.first.target).to eq(:next_step)
      expect(node.visibility_rule).to be_a(FlowEngine::Rules::Equals)
    end

    it "creates a Node with fields" do
      builder.type :number_matrix
      builder.question "How many?"
      builder.fields %w[A B C]

      node = builder.build(:biz)
      expect(node.fields).to eq(%w[A B C])
    end

    it "creates a Node with no transitions" do
      builder.type :text
      builder.question "Thanks"

      node = builder.build(:done)
      expect(node.transitions).to be_empty
    end

    it "supports unconditional transitions" do
      builder.type :text
      builder.question "Question"
      builder.transition to: :next

      node = builder.build(:step1)
      expect(node.transitions.first.rule).to be_nil
      expect(node.transitions.first.condition_label).to eq("always")
    end

    it "creates a Node with decorations" do
      builder.type :text
      builder.question "Tell us about yourself"
      builder.decorations({ hint: "Be detailed", icon: "pencil" })

      node = builder.build(:intro)
      expect(node).to be_frozen
    end

    it "creates an ai_intake Node with max_clarifications" do
      builder.type :ai_intake
      builder.question "Describe your situation"
      builder.max_clarifications 5

      node = builder.build(:intake)
      expect(node.ai_intake?).to be true
      expect(node.max_clarifications).to eq(5)
    end

    it "creates a Node with hash options (key => label)" do
      builder.type :single_select
      builder.question "Filing status?"
      builder.options({ "single" => "Single", "mfj" => "Married Filing Jointly" })

      node = builder.build(:filing_status)
      expect(node.options).to eq(%w[single mfj])
      expect(node.option_labels).to eq("single" => "Single", "mfj" => "Married Filing Jointly")
    end
  end
end
