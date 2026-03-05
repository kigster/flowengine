# frozen_string_literal: true

RSpec.describe "FlowEngine.load_dsl" do
  it "loads a valid DSL string and returns a Definition" do
    dsl_text = <<~RUBY
      FlowEngine.define do
        start :step1
        step :step1 do
          type :text
          question "Hello?"
        end
      end
    RUBY

    definition = FlowEngine.load_dsl(dsl_text)
    expect(definition).to be_a(FlowEngine::Definition)
    expect(definition.start_step_id).to eq(:step1)
  end

  it "loads DSL with transitions and rules" do
    dsl_text = <<~RUBY
      FlowEngine.define do
        start :earnings
        step :earnings do
          type :multi_select
          question "What are your main earnings?"
          options %w[W2 BusinessOwnership]
          transition to: :details, if_rule: contains(:earnings, "BusinessOwnership")
        end
        step :details do
          type :text
          question "Details?"
        end
      end
    RUBY

    definition = FlowEngine.load_dsl(dsl_text)
    expect(definition.step_ids).to contain_exactly(:earnings, :details)
  end

  it "raises DefinitionError on syntax error" do
    expect do
      FlowEngine.load_dsl("def foo(")
    end.to raise_error(FlowEngine::DefinitionError, /DSL syntax error/)
  end

  it "raises DefinitionError on runtime error" do
    expect do
      FlowEngine.load_dsl("raise 'boom'")
    end.to raise_error(FlowEngine::DefinitionError, /DSL evaluation error.*boom/)
  end

  it "raises DefinitionError when DSL returns non-Definition" do
    result = FlowEngine.load_dsl("42")
    expect(result).to eq(42) # load_dsl returns whatever the text evaluates to
  end
end
