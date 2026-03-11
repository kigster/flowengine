# frozen_string_literal: true

require "json"
require "rspec"
require "rspec/its"

# Integration test: a financial advisor intake with two AI intake steps.
# The first collects personal/tax info, the second collects financial details.
RSpec.describe "Multi-AI Intake Flow", :integration do
  let(:definition) do
    FlowEngine.define do
      start :personal_intake

      # First AI intake: collect personal and tax information
      step :personal_intake do
        type :ai_intake
        question "Tell us about yourself and your tax situation"
        max_clarifications 2
        transition to: :filing_status
      end

      step :filing_status do
        type :single_select
        question "What is your filing status?"
        options %w[single married_joint married_separate head_of_household]
        transition to: :dependents
      end

      step :dependents do
        type :number
        question "How many dependents do you claim?"
        transition to: :income_types
      end

      step :income_types do
        type :multi_select
        question "Select all income types that apply"
        options %w[W2 1099 Business Investment Rental]
        transition to: :state
      end

      step :state do
        type :text
        question "Which state do you primarily reside in?"
        transition to: :financial_intake
      end

      # Second AI intake: collect financial details mid-flow
      step :financial_intake do
        type :ai_intake
        question "Describe your financial situation: bank accounts, debts, investments, and deductions"
        max_clarifications 3
        transition to: :annual_income
      end

      step :annual_income do
        type :number
        question "What is your total annual income?"
        transition to: :deductions
      end

      step :deductions do
        type :multi_select
        question "Select all deductions that apply"
        options %w[mortgage student_loans charitable medical home_office]
        transition to: :retirement_contributions
      end

      step :retirement_contributions do
        type :number
        question "Total retirement contributions this year (401k, IRA, etc.)?"
        transition to: :summary
      end

      step :summary do
        type :text
        question "Any additional notes for your advisor?"
      end
    end
  end

  let(:adapter) { instance_double(FlowEngine::LLM::Adapter) }
  let(:llm_client) { FlowEngine::LLM::Client.new(adapter: adapter, model: "test-model") }

  subject(:engine) { FlowEngine::Engine.new(definition) }

  it "has two ai_intake steps" do
    intake_steps = definition.steps.values.select(&:ai_intake?)
    expect(intake_steps.map(&:id)).to eq(%i[personal_intake financial_intake])
  end

  describe "complete flow with two AI intake steps" do
    it "fills most questions via AI with minimal manual answers" do
      # === Round 1: Personal intake ===
      expect(engine.current_step.ai_intake?).to be true

      allow(adapter).to receive(:chat).and_return({
        answers: { filing_status: "married_joint", dependents: 2 },
        follow_up: "What types of income do you have?"
      }.to_json)

      r1 = engine.submit_ai_intake(
        "I'm married filing jointly, 2 kids. We live in California.",
        llm_client: llm_client
      )
      expect(r1.done?).to be false
      expect(r1.follow_up).to include("income")
      expect(engine.answers[:filing_status]).to eq("married_joint")

      # Round 1 clarification
      allow(adapter).to receive(:chat).and_return({
        answers: { income_types: %w[W2 Business], state: "California" },
        follow_up: nil
      }.to_json)

      r2 = engine.submit_clarification(
        "W2 from my employer and a small business. We're in California.",
        llm_client: llm_client
      )
      expect(r2.done?).to be true

      # All personal steps should be filled — engine should advance to financial_intake
      expect(engine.current_step_id).to eq(:financial_intake)
      expect(engine.current_step.ai_intake?).to be true

      # === Round 2: Financial intake ===
      allow(adapter).to receive(:chat).and_return({
        answers: { annual_income: 125_000, deductions: %w[mortgage charitable] },
        follow_up: "Do you have retirement contributions?"
      }.to_json)

      r3 = engine.submit_ai_intake(
        "Household income is about 125k. We have a mortgage and donate to charity.",
        llm_client: llm_client
      )
      expect(r3.done?).to be false
      expect(r3.follow_up).to include("retirement")

      # Round 2 clarification
      allow(adapter).to receive(:chat).and_return({
        answers: { retirement_contributions: 12_000 },
        follow_up: nil
      }.to_json)

      r4 = engine.submit_clarification(
        "Yes, I put about 12k into my 401k this year",
        llm_client: llm_client
      )
      expect(r4.done?).to be true

      # Engine should advance past all pre-filled steps to the final step
      expect(engine.current_step_id).to eq(:summary)

      # Manually answer the final open-ended question
      engine.answer("Looking forward to working with you!")
      expect(engine.finished?).to be true

      # Verify all answers are collected
      expect(engine.answers[:filing_status]).to eq("married_joint")
      expect(engine.answers[:dependents]).to eq(2)
      expect(engine.answers[:income_types]).to eq(%w[W2 Business])
      expect(engine.answers[:state]).to eq("California")
      expect(engine.answers[:annual_income]).to eq(125_000)
      expect(engine.answers[:deductions]).to eq(%w[mortgage charitable])
      expect(engine.answers[:retirement_contributions]).to eq(12_000)
      expect(engine.answers[:summary]).to eq("Looking forward to working with you!")
    end
  end

  describe "AI intake with state persistence across both intakes" do
    it "round-trips through JSON between the two intake steps" do
      # Complete first intake
      allow(adapter).to receive(:chat).and_return({
        answers: { filing_status: "single", dependents: 0, income_types: ["W2"], state: "NY" },
        follow_up: nil
      }.to_json)

      engine.submit_ai_intake("Single, no kids, W2 only, NYC", llm_client: llm_client)
      expect(engine.current_step_id).to eq(:financial_intake)

      # Serialize, round-trip through JSON, and restore
      json = engine.to_state.to_json
      parsed = JSON.parse(json)
      restored = FlowEngine::Engine.from_state(definition, parsed)

      expect(restored.current_step_id).to eq(:financial_intake)
      expect(restored.answers[:filing_status]).to eq("single")
      expect(restored.current_step.ai_intake?).to be true

      # Continue with second intake on restored engine
      allow(adapter).to receive(:chat).and_return({
        answers: { annual_income: 85_000, deductions: ["student_loans"], retirement_contributions: 6000 },
        follow_up: nil
      }.to_json)

      result = restored.submit_ai_intake("85k salary, student loans, 6k in IRA", llm_client: llm_client)
      expect(result.done?).to be true
      expect(restored.current_step_id).to eq(:summary)
    end
  end

  describe "AI intake with max_clarifications exhausted" do
    it "finalizes after hitting the max even with pending follow-ups" do
      # First intake: hit max_clarifications (2)
      allow(adapter).to receive(:chat).and_return({
        answers: { filing_status: "single" },
        follow_up: "How many dependents?"
      }.to_json)
      engine.submit_ai_intake("I'm single", llm_client: llm_client)

      allow(adapter).to receive(:chat).and_return({
        answers: { dependents: 0 },
        follow_up: "What income types?"
      }.to_json)
      engine.submit_clarification("None", llm_client: llm_client)

      # Third round — hits max (2 clarifications after initial)
      allow(adapter).to receive(:chat).and_return({
        answers: { income_types: ["W2"] },
        follow_up: "Which state?"
      }.to_json)
      r = engine.submit_clarification("W2", llm_client: llm_client)

      # Should be done despite follow_up, because max_clarifications=2 was exceeded
      expect(r.done?).to be true
      expect(r.follow_up).to be_nil

      # Engine advances past pre-filled steps, stops at unanswered :state
      expect(engine.current_step_id).to eq(:state)

      # Manually complete the rest
      engine.answer("Texas")
      expect(engine.current_step_id).to eq(:financial_intake)
    end
  end
end
