# frozen_string_literal: true

RSpec.describe "Introduction flow integration" do
  let(:definition) do
    FlowEngine.define do
      start :filing_status

      introduction label: "Tell us about your tax situation",
                   placeholder: "Describe your filing status, income sources, and any special circumstances"

      step :filing_status do
        type :single_select
        question "What is your filing status for 2025?"
        options %w[single married_filing_jointly married_filing_separately head_of_household]
        transition to: :dependents
      end

      step :dependents do
        type :number
        question "How many dependents do you have?"
        transition to: :income_types
      end

      step :income_types do
        type :multi_select
        question "Select all income types that apply"
        options %w[W2 1099 Business Investment Rental Retirement]
        transition to: :business_count, if_rule: contains(:income_types, "Business")
        transition to: :contact_info
      end

      step :business_count do
        type :number
        question "How many businesses do you own?"
        transition to: :contact_info
      end

      step :contact_info do
        type :text
        question "Your name and preferred email?"
      end
    end
  end

  let(:adapter) { instance_double(FlowEngine::LLM::Adapter) }
  let(:llm_client) { FlowEngine::LLM::Client.new(adapter: adapter, model: "gpt-4o-mini") }

  describe "LLM pre-fills and user completes remaining steps" do
    it "skips pre-filled steps and continues from the first unanswered one" do
      allow(adapter).to receive(:chat).and_return(
        '{"filing_status": "married_filing_jointly", "dependents": 3, "income_types": ["W2", "Business"]}'
      )

      engine = FlowEngine::Engine.new(definition)
      engine.submit_introduction(
        "We are married filing jointly, have 3 kids, I get a W2 and my wife has a small business",
        llm_client: llm_client
      )

      # Pre-filled steps were auto-advanced; now at business_count (branched via contains rule)
      expect(engine.current_step_id).to eq(:business_count)
      expect(engine.answers[:filing_status]).to eq("married_filing_jointly")
      expect(engine.answers[:dependents]).to eq(3)
      expect(engine.answers[:income_types]).to eq(%w[W2 Business])

      # User manually answers remaining steps
      engine.answer(1)
      expect(engine.current_step_id).to eq(:contact_info)

      engine.answer("Jane Doe, jane@example.com")
      expect(engine.finished?).to be true

      # Full state roundtrip
      state = engine.to_state
      restored = FlowEngine::Engine.from_state(definition, state)
      expect(restored.finished?).to be true
      expect(restored.introduction_text).to eq(
        "We are married filing jointly, have 3 kids, I get a W2 and my wife has a small business"
      )
      expect(restored.answers).to eq(engine.answers)
    end
  end

  describe "sensitive data rejection" do
    it "rejects introduction with SSN and does not modify engine state" do
      engine = FlowEngine::Engine.new(definition)

      expect do
        engine.submit_introduction("My SSN is 123-45-6789 and I am single", llm_client: llm_client)
      end.to raise_error(FlowEngine::SensitiveDataError)

      expect(engine.current_step_id).to eq(:filing_status)
      expect(engine.answers).to eq({})
      expect(engine.introduction_text).to be_nil
    end
  end

  describe "definition without introduction" do
    let(:simple_definition) do
      FlowEngine.define do
        start :name

        step :name do
          type :text
          question "What is your name?"
        end
      end
    end

    it "has nil introduction" do
      expect(simple_definition.introduction).to be_nil
    end

    it "works normally without introduction" do
      engine = FlowEngine::Engine.new(simple_definition)
      engine.answer("Alice")
      expect(engine.finished?).to be true
    end
  end
end
