# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::Client do
  let(:adapter) { instance_double(FlowEngine::LLM::Adapter) }
  let(:model) { "gpt-4o-mini" }

  subject(:client) { described_class.new(adapter: adapter, model: model) }

  let(:definition) do
    FlowEngine.define do
      start :filing_status

      step :filing_status do
        type :single_select
        question "What is your filing status?"
        options %w[single married_filing_jointly head_of_household]
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
      end
    end
  end

  describe "#to_s" do
    it "includes class name, adapter, and model" do
      text = client.to_s
      expect(text).to include("FlowEngine::LLM::Client")
      expect(text).to include("gpt-4o-mini")
    end
  end

  describe "#parse_introduction" do
    context "when LLM returns valid JSON" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"filing_status": "single", "dependents": 2, "income_types": ["W2", "Business"]}'
        )
      end

      subject(:result) do
        client.parse_introduction(
          definition: definition,
          introduction_text: "I am single with 2 kids"
        )
      end

      it { is_expected.to be_a(Hash) }

      it "extracts filing_status as a string" do
        expect(result[:filing_status]).to eq("single")
      end

      it "extracts dependents as a number" do
        expect(result[:dependents]).to eq(2)
      end

      it "extracts income_types as an array" do
        expect(result[:income_types]).to eq(%w[W2 Business])
      end
    end

    context "when LLM returns JSON wrapped in code fences" do
      before do
        allow(adapter).to receive(:chat).and_return(
          "```json\n{\"filing_status\": \"married_filing_jointly\"}\n```"
        )
      end

      it "extracts JSON from code fences" do
        result =
          client.parse_introduction(
            definition: definition,
            introduction_text: "test"
          )
        expect(result[:filing_status]).to eq("married_filing_jointly")
      end
    end

    context "when LLM returns partial answers" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"filing_status": "single"}'
        )
      end

      it "only includes steps the LLM extracted" do
        result =
          client.parse_introduction(
            definition: definition,
            introduction_text: "I am single"
          )
        expect(result.keys).to eq([:filing_status])
      end
    end

    context "when LLM returns unknown step IDs" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"filing_status": "single", "unknown_step": "ignored"}'
        )
      end

      it "ignores step IDs not in the definition" do
        result =
          client.parse_introduction(
            definition: definition,
            introduction_text: "test"
          )
        expect(result.keys).to eq([:filing_status])
        expect(result).not_to have_key(:unknown_step)
      end
    end

    context "when LLM returns invalid JSON" do
      before do
        allow(adapter).to receive(:chat).and_return("not valid json at all")
      end

      it "raises LLMError" do
        expect do
          client.parse_introduction(
            definition: definition,
            introduction_text: "test"
          )
        end.to raise_error(FlowEngine::Errors::LLMError, /Failed to parse/)
      end
    end

    context "with number_matrix step" do
      let(:definition) do
        FlowEngine.define do
          start :business_details

          step :business_details do
            type :number_matrix
            question "How many of each business type?"
            fields %w[RealEstate LLC SCorp]
          end
        end
      end

      before do
        allow(adapter).to receive(:chat).and_return(
          '{"business_details": {"RealEstate": 2, "LLC": 1}}'
        )
      end

      it "coerces number_matrix values to integers" do
        result =
          client.parse_introduction(
            definition: definition,
            introduction_text: "test"
          )
        expect(result[:business_details]).to eq({ RealEstate: 2, LLC: 1 })
      end
    end

    it "passes the correct model to the adapter" do
      allow(adapter).to receive(:chat).and_return("{}")
      client.parse_introduction(
        definition: definition,
        introduction_text: "test"
      )
      expect(adapter).to have_received(:chat).with(
        system_prompt: a_kind_of(String),
        user_prompt: "test",
        model: "gpt-4o-mini"
      )
    end
  end

  describe "#parse_ai_intake" do
    let(:intake_definition) do
      FlowEngine.define do
        start :intake

        step :intake do
          type :ai_intake
          question "Tell us about yourself"
          max_clarifications 2
          transition to: :filing_status
        end

        step :filing_status do
          type :single_select
          question "Filing status?"
          options %w[single married_joint]
          transition to: :dependents
        end

        step :dependents do
          type :number
          question "How many dependents?"
        end
      end
    end

    context "when LLM returns answers with follow-up" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"filing_status": "single"}, "follow_up": "How many dependents?"}'
        )
      end

      subject(:result) do
        client.parse_ai_intake(definition: intake_definition, user_text: "I'm single")
      end

      it "returns a hash with answers and follow_up" do
        expect(result[:answers]).to eq(filing_status: "single")
        expect(result[:follow_up]).to eq("How many dependents?")
      end
    end

    context "when LLM returns answers without follow-up" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"filing_status": "single", "dependents": 0}, "follow_up": null}'
        )
      end

      subject(:result) do
        client.parse_ai_intake(definition: intake_definition, user_text: "I'm single, no kids")
      end

      it "returns nil follow_up" do
        expect(result[:follow_up]).to be_nil
      end

      it "extracts all answers" do
        expect(result[:answers]).to eq(filing_status: "single", dependents: 0)
      end
    end

    context "when LLM returns unknown step IDs" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"filing_status": "single", "bogus": "ignored"}, "follow_up": null}'
        )
      end

      it "ignores unknown steps" do
        result = client.parse_ai_intake(definition: intake_definition, user_text: "test")
        expect(result[:answers].keys).to eq([:filing_status])
      end
    end

    context "when LLM returns invalid JSON" do
      before do
        allow(adapter).to receive(:chat).and_return("not json")
      end

      it "raises LLMError" do
        expect do
          client.parse_ai_intake(definition: intake_definition, user_text: "test")
        end.to raise_error(FlowEngine::Errors::LLMError, /Failed to parse/)
      end
    end

    context "with conversation history" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"answers": {"dependents": 2}, "follow_up": null}'
        )
      end

      it "passes answered and history to the prompt builder" do
        client.parse_ai_intake(
          definition: intake_definition,
          user_text: "2 kids",
          answered: { filing_status: "single" },
          conversation_history: [
            { role: :user, text: "I'm single" },
            { role: :assistant, text: "How many dependents?" }
          ]
        )
        expect(adapter).to have_received(:chat).with(
          system_prompt: a_string_including("Already Answered"),
          user_prompt: "2 kids",
          model: "gpt-4o-mini"
        )
      end
    end

    context "with code-fenced JSON response" do
      before do
        allow(adapter).to receive(:chat).and_return(
          "```json\n{\"answers\": {\"filing_status\": \"single\"}, \"follow_up\": null}\n```"
        )
      end

      it "extracts JSON from code fences" do
        result = client.parse_ai_intake(definition: intake_definition, user_text: "test")
        expect(result[:answers]).to eq(filing_status: "single")
      end
    end
  end
end
