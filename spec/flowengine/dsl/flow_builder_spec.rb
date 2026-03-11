# frozen_string_literal: true

RSpec.describe FlowEngine::DSL::FlowBuilder do
  subject(:builder) { described_class.new }

  describe "#build" do
    it "creates a Definition from DSL" do
      builder.start :step1

      builder.step :step1 do
        type :text
        question "Hello"
        transition to: :step2
      end

      builder.step :step2 do
        type :text
        question "Goodbye"
      end

      definition = builder.build

      expect(definition).to be_a(FlowEngine::Definition)
      expect(definition.start_step_id).to eq(:step1)
      expect(definition.step_ids).to contain_exactly(:step1, :step2)
    end

    it "raises DefinitionError when no start step defined" do
      builder.step :step1 do
        type :text
        question "Hello"
      end

      expect { builder.build }.to raise_error(
        FlowEngine::Errors::DefinitionError,
        /No start step/
      )
    end

    it "raises DefinitionError when no steps defined" do
      builder.start :step1

      expect { builder.build }.to raise_error(
        FlowEngine::Errors::DefinitionError,
        /No steps/
      )
    end

    it "supports rule helpers in flow builder context" do
      builder.start :step1

      builder.step :step1 do
        type :multi_select
        question "Earnings?"
        options %w[W2 1099]
        transition to: :step2, if_rule: contains(:step1, "W2")
      end

      builder.step :step2 do
        type :text
        question "Done"
      end

      definition = builder.build
      node = definition.step(:step1)
      expect(node.transitions.first.rule).to be_a(FlowEngine::Rules::Contains)
    end
  end
end
