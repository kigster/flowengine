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

  describe "#parse_introduction" do
    context "when LLM returns valid JSON" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"filing_status": "single", "dependents": 2, "income_types": ["W2", "Business"]}'
        )
      end

      subject(:result) do
        client.parse_introduction(definition: definition, introduction_text: "I am single with 2 kids")
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
        result = client.parse_introduction(definition: definition, introduction_text: "test")
        expect(result[:filing_status]).to eq("married_filing_jointly")
      end
    end

    context "when LLM returns partial answers" do
      before do
        allow(adapter).to receive(:chat).and_return('{"filing_status": "single"}')
      end

      it "only includes steps the LLM extracted" do
        result = client.parse_introduction(definition: definition, introduction_text: "I am single")
        expect(result.keys).to eq([:filing_status])
      end
    end

    context "when LLM returns unknown step IDs" do
      before do
        allow(adapter).to receive(:chat).and_return('{"filing_status": "single", "unknown_step": "ignored"}')
      end

      it "ignores step IDs not in the definition" do
        result = client.parse_introduction(definition: definition, introduction_text: "test")
        expect(result.keys).to eq([:filing_status])
        expect(result).not_to have_key(:unknown_step)
      end
    end

    context "when LLM returns invalid JSON" do
      before do
        allow(adapter).to receive(:chat).and_return("not valid json at all")
      end

      it "raises LLMError" do
        expect { client.parse_introduction(definition: definition, introduction_text: "test") }
          .to raise_error(FlowEngine::LLMError, /Failed to parse/)
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
        result = client.parse_introduction(definition: definition, introduction_text: "test")
        expect(result[:business_details]).to eq({ RealEstate: 2, LLC: 1 })
      end
    end

    it "passes the correct model to the adapter" do
      allow(adapter).to receive(:chat).and_return("{}")
      client.parse_introduction(definition: definition, introduction_text: "test")
      expect(adapter).to have_received(:chat).with(
        system_prompt: a_kind_of(String),
        user_prompt: "test",
        model: "gpt-4o-mini"
      )
    end
  end
end
