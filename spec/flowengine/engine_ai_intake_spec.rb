# frozen_string_literal: true

require "json"
require "rspec"
require "rspec/its"

RSpec.describe FlowEngine::Engine, "AI intake" do
  let(:definition) do
    FlowEngine.define do
      start :welcome_intake

      step :welcome_intake do
        type :ai_intake
        question "Tell us about your tax situation"
        max_clarifications 3
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
        question "How many dependents?"
        transition to: :income_types
      end

      step :income_types do
        type :multi_select
        question "Select income types"
        options %w[W2 1099 Business Investment]
        transition to: :state_info
      end

      step :state_info do
        type :text
        question "Which state do you live in?"
      end
    end
  end

  let(:adapter) { instance_double(FlowEngine::LLM::Adapter) }
  let(:llm_client) { FlowEngine::LLM::Client.new(adapter: adapter, model: "test-model") }

  subject(:engine) { described_class.new(definition) }

  describe "ai_intake step in definition" do
    subject(:node) { definition.step(:welcome_intake) }

    its(:type) { is_expected.to eq(:ai_intake) }
    its(:max_clarifications) { is_expected.to eq(3) }
    its(:ai_intake?) { is_expected.to be true }
  end

  describe "non-ai_intake step" do
    subject(:node) { definition.step(:filing_status) }

    its(:ai_intake?) { is_expected.to be false }
    its(:max_clarifications) { is_expected.to eq(0) }
  end

  describe "#submit_ai_intake" do
    context "when LLM extracts some answers with a follow-up" do
      before do
        response = {
          answers: { filing_status: "married_joint", dependents: 2 },
          follow_up: "What types of income do you have?"
        }.to_json
        allow(adapter).to receive(:chat).and_return(response)
      end

      it "returns a ClarificationResult with follow-up" do
        result = engine.submit_ai_intake("I'm married with 2 kids", llm_client: llm_client)
        expect(result).to be_a(FlowEngine::ClarificationResult)
        expect(result.follow_up).to eq("What types of income do you have?")
        expect(result.round).to eq(1)
        expect(result.done?).to be false
      end

      it "merges extracted answers" do
        engine.submit_ai_intake("I'm married with 2 kids", llm_client: llm_client)
        expect(engine.answers[:filing_status]).to eq("married_joint")
        expect(engine.answers[:dependents]).to eq(2)
      end

      it "stays at the AI intake step while clarifying" do
        engine.submit_ai_intake("I'm married with 2 kids", llm_client: llm_client)
        expect(engine.current_step_id).to eq(:welcome_intake)
      end

      it "reports pending steps" do
        result = engine.submit_ai_intake("I'm married with 2 kids", llm_client: llm_client)
        expect(result.pending_steps).to include(:income_types, :state_info)
        expect(result.pending_steps).not_to include(:filing_status, :dependents)
      end
    end

    context "when LLM extracts answers with no follow-up" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"filing_status": "single", "dependents": 0}, "follow_up": null}'
        )
      end

      it "advances past the intake and pre-filled steps" do
        result = engine.submit_ai_intake("I'm single, no dependents", llm_client: llm_client)
        expect(result.done?).to be true
        expect(engine.current_step_id).to eq(:income_types)
      end

      it "records the intake step answer as conversation summary" do
        engine.submit_ai_intake("I'm single, no dependents", llm_client: llm_client)
        expect(engine.answers[:welcome_intake]).to include("I'm single, no dependents")
      end
    end

    context "when LLM extracts all remaining answers" do
      before do
        response = {
          answers: { filing_status: "single", dependents: 0, income_types: ["W2"], state_info: "California" },
          follow_up: nil
        }.to_json
        allow(adapter).to receive(:chat).and_return(response)
      end

      it "finishes the flow" do
        engine.submit_ai_intake("I'm single, no kids, W2 in California", llm_client: llm_client)
        expect(engine.finished?).to be true
      end
    end

    context "when current step is not ai_intake" do
      before do
        # Force engine to a non-intake step
        allow(adapter).to receive(:chat).and_return('{"answers": {}, "follow_up": null}')
        engine.submit_ai_intake("test", llm_client: llm_client)
      end

      it "raises EngineError" do
        expect { engine.submit_ai_intake("test", llm_client: llm_client) }
          .to raise_error(FlowEngine::Errors::EngineError, /not an AI intake/)
      end
    end

    context "with sensitive data" do
      it "raises SensitiveDataError" do
        expect { engine.submit_ai_intake("My SSN is 123-45-6789", llm_client: llm_client) }
          .to raise_error(FlowEngine::Errors::SensitiveDataError)
      end

      it "does not call the LLM" do
        allow(adapter).to receive(:chat)
        begin
          engine.submit_ai_intake("SSN: 123-45-6789", llm_client: llm_client)
        rescue FlowEngine::Errors::SensitiveDataError
          # expected
        end
        expect(adapter).not_to have_received(:chat)
      end
    end
  end

  describe "#submit_clarification" do
    context "multi-round conversation" do
      it "completes a 3-round intake" do
        # Round 1: initial
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"filing_status": "married_joint"}, "follow_up": "How many dependents?"}'
        )
        r1 = engine.submit_ai_intake("I'm married", llm_client: llm_client)
        expect(r1.round).to eq(1)
        expect(r1.done?).to be false

        # Round 2: first clarification
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"dependents": 2}, "follow_up": "What types of income?"}'
        )
        r2 = engine.submit_clarification("2 kids", llm_client: llm_client)
        expect(r2.round).to eq(2)
        expect(r2.done?).to be false

        # Round 3: second clarification
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"income_types": ["W2"]}, "follow_up": "Which state?"}'
        )
        r3 = engine.submit_clarification("W2 income", llm_client: llm_client)
        expect(r3.round).to eq(3)
        expect(r3.done?).to be false

        # Round 4: hits max_clarifications (3), so done regardless of follow_up
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"state_info": "NY"}, "follow_up": "anything else?"}'
        )
        r4 = engine.submit_clarification("New York", llm_client: llm_client)
        expect(r4.round).to eq(4)
        expect(r4.done?).to be true
        expect(engine.finished?).to be true
      end
    end

    context "when no active intake conversation" do
      it "raises EngineError" do
        expect { engine.submit_clarification("text", llm_client: llm_client) }
          .to raise_error(FlowEngine::Errors::EngineError, /No active AI intake/)
      end
    end

    context "with sensitive data in clarification" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {}, "follow_up": "Tell me more"}'
        )
        engine.submit_ai_intake("hello", llm_client: llm_client)
      end

      it "raises SensitiveDataError" do
        expect { engine.submit_clarification("My SSN is 123-45-6789", llm_client: llm_client) }
          .to raise_error(FlowEngine::Errors::SensitiveDataError)
      end
    end
  end

  describe "state persistence with AI intake" do
    before do
      allow(adapter).to receive(:chat).and_return(
        '{"answers": {"filing_status": "single"}, "follow_up": "How many dependents?"}'
      )
      engine.submit_ai_intake("I'm single", llm_client: llm_client)
    end

    describe "#to_state" do
      subject(:state) { engine.to_state }

      it "includes clarification_round" do
        expect(state[:clarification_round]).to eq(1)
      end

      it "includes conversation_history" do
        expect(state[:conversation_history].length).to eq(2)
        expect(state[:conversation_history].first[:role]).to eq(:user)
        expect(state[:conversation_history].last[:role]).to eq(:assistant)
      end

      it "includes active_intake_step_id" do
        expect(state[:active_intake_step_id]).to eq(:welcome_intake)
      end
    end

    describe ".from_state" do
      let(:state) do
        {
          current_step_id: :welcome_intake,
          answers: { filing_status: "single" },
          history: %i[welcome_intake],
          clarification_round: 1,
          conversation_history: [
            { role: :user, text: "I'm single" },
            { role: :assistant, text: "How many dependents?" }
          ],
          active_intake_step_id: :welcome_intake
        }
      end

      subject(:restored) { described_class.from_state(definition, state) }

      its(:clarification_round) { is_expected.to eq(1) }
      its(:current_step_id) { is_expected.to eq(:welcome_intake) }

      it "preserves conversation_history" do
        expect(restored.conversation_history.length).to eq(2)
      end

      it "allows continuing clarification" do
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"dependents": 0}, "follow_up": null}'
        )
        result = restored.submit_clarification("no kids", llm_client: llm_client)
        expect(result.done?).to be true
      end
    end

    describe ".from_state with string keys (JSON round-trip)" do
      let(:state) do
        {
          "current_step_id" => "welcome_intake",
          "answers" => { "filing_status" => "single" },
          "history" => %w[welcome_intake],
          "clarification_round" => 1,
          "conversation_history" => [
            { "role" => "user", "text" => "I'm single" },
            { "role" => "assistant", "text" => "How many dependents?" }
          ],
          "active_intake_step_id" => "welcome_intake"
        }
      end

      subject(:restored) { described_class.from_state(definition, state) }

      its(:current_step_id) { is_expected.to eq(:welcome_intake) }
      its(:clarification_round) { is_expected.to eq(1) }

      it "symbolizes conversation history roles" do
        expect(restored.conversation_history.first[:role]).to eq(:user)
      end
    end
  end

  describe "mid-flow AI intake" do
    let(:mid_flow_definition) do
      FlowEngine.define do
        start :filing_status

        step :filing_status do
          type :single_select
          question "Filing status?"
          options %w[single married_joint]
          transition to: :financial_intake
        end

        step :financial_intake do
          type :ai_intake
          question "Describe your financial situation"
          max_clarifications 2
          transition to: :income_amount
        end

        step :income_amount do
          type :number
          question "Total annual income?"
          transition to: :deductions
        end

        step :deductions do
          type :multi_select
          question "Select deductions"
          options %w[mortgage student_loans charitable medical]
        end
      end
    end

    subject(:engine) { described_class.new(mid_flow_definition) }

    it "reaches the AI intake step after answering the first step" do
      engine.answer("single")
      expect(engine.current_step_id).to eq(:financial_intake)
      expect(engine.current_step.ai_intake?).to be true
    end

    it "fills subsequent steps from the AI intake" do
      engine.answer("single")

      allow(adapter).to receive(:chat).and_return(
        '{"answers": {"income_amount": 85000, "deductions": ["mortgage"]}, "follow_up": null}'
      )
      result = engine.submit_ai_intake("I make 85k and have a mortgage", llm_client: llm_client)

      expect(result.done?).to be true
      expect(engine.finished?).to be true
      expect(engine.answers[:income_amount]).to eq(85_000)
      expect(engine.answers[:deductions]).to eq(["mortgage"])
    end
  end
end
