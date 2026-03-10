# frozen_string_literal: true

RSpec.describe FlowEngine::Engine, "introduction" do
  let(:definition) do
    FlowEngine.define do
      start :filing_status

      introduction label: "Tell us about your tax situation",
                   placeholder: "e.g. I am married, filing jointly, with 2 dependents..."

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
        transition to: :state_info
      end

      step :state_info do
        type :text
        question "Which state do you live in?"
      end
    end
  end

  let(:adapter) { instance_double(FlowEngine::LLM::Adapter) }
  let(:llm_client) { FlowEngine::LLM::Client.new(adapter: adapter, model: "gpt-4o-mini") }

  subject(:engine) { described_class.new(definition) }

  describe "definition with introduction" do
    subject(:intro) { definition.introduction }

    it { is_expected.not_to be_nil }
    its(:label) { is_expected.to eq("Tell us about your tax situation") }
    its(:placeholder) { is_expected.to include("married, filing jointly") }
  end

  describe "#submit_introduction" do
    context "when LLM extracts first two steps" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"filing_status": "married_filing_jointly", "dependents": 2}'
        )
      end

      it "stores the introduction text" do
        engine.submit_introduction("I am married filing jointly with 2 dependents", llm_client: llm_client)
        expect(engine.introduction_text).to eq("I am married filing jointly with 2 dependents")
      end

      it "pre-fills answers from the LLM" do
        engine.submit_introduction("I am married filing jointly with 2 dependents", llm_client: llm_client)
        expect(engine.answers[:filing_status]).to eq("married_filing_jointly")
        expect(engine.answers[:dependents]).to eq(2)
      end

      it "auto-advances past pre-filled steps" do
        engine.submit_introduction("I am married filing jointly with 2 dependents", llm_client: llm_client)
        expect(engine.current_step_id).to eq(:income_types)
      end

      it "records pre-filled steps in history" do
        engine.submit_introduction("I am married filing jointly with 2 dependents", llm_client: llm_client)
        expect(engine.history).to eq(%i[filing_status dependents income_types])
      end

      it "allows continuing the flow from the first unanswered step" do
        engine.submit_introduction("I am married filing jointly with 2 dependents", llm_client: llm_client)
        engine.answer(%w[W2 Business])
        expect(engine.current_step_id).to eq(:state_info)
      end
    end

    context "when LLM extracts all steps" do
      before do
        allow(adapter).to receive(:chat).and_return(
          '{"filing_status": "single", "dependents": 0, "income_types": ["W2"], "state_info": "California"}'
        )
      end

      it "finishes the flow" do
        engine.submit_introduction("I'm single, no dependents, W2 only, live in California", llm_client: llm_client)
        expect(engine.finished?).to be true
      end
    end

    context "when LLM extracts nothing" do
      before do
        allow(adapter).to receive(:chat).and_return("{}")
      end

      it "stays at the first step" do
        engine.submit_introduction("hello", llm_client: llm_client)
        expect(engine.current_step_id).to eq(:filing_status)
      end

      it "stores the introduction text anyway" do
        engine.submit_introduction("hello", llm_client: llm_client)
        expect(engine.introduction_text).to eq("hello")
      end
    end

    context "with sensitive data" do
      it "raises SensitiveDataError for SSN" do
        expect { engine.submit_introduction("My SSN is 123-45-6789", llm_client: llm_client) }
          .to raise_error(FlowEngine::SensitiveDataError, /sensitive information/)
      end

      it "raises SensitiveDataError for EIN" do
        expect { engine.submit_introduction("Business EIN 12-3456789", llm_client: llm_client) }
          .to raise_error(FlowEngine::SensitiveDataError, /sensitive information/)
      end

      it "does not store introduction text when sensitive data is detected" do
        begin
          engine.submit_introduction("SSN: 123-45-6789", llm_client: llm_client)
        rescue FlowEngine::SensitiveDataError
          # expected
        end
        expect(engine.introduction_text).to be_nil
      end

      it "does not call the LLM when sensitive data is detected" do
        allow(adapter).to receive(:chat)
        begin
          engine.submit_introduction("SSN: 123-45-6789", llm_client: llm_client)
        rescue FlowEngine::SensitiveDataError
          # expected
        end
        expect(adapter).not_to have_received(:chat)
      end
    end

    context "with maxlength exceeded" do
      let(:definition) do
        FlowEngine.define do
          start :name
          introduction label: "Brief intro", maxlength: 20

          step :name do
            type :text
            question "Your name?"
          end
        end
      end

      it "raises ValidationError when text exceeds maxlength" do
        expect { engine.submit_introduction("A" * 21, llm_client: llm_client) }
          .to raise_error(FlowEngine::ValidationError, %r{maxlength.*21/20})
      end

      it "accepts text within maxlength" do
        allow(adapter).to receive(:chat).and_return("{}")
        expect { engine.submit_introduction("A" * 20, llm_client: llm_client) }.not_to raise_error
      end

      it "does not call the LLM when maxlength is exceeded" do
        allow(adapter).to receive(:chat)
        begin
          engine.submit_introduction("A" * 21, llm_client: llm_client)
        rescue FlowEngine::ValidationError
          # expected
        end
        expect(adapter).not_to have_received(:chat)
      end
    end
  end

  describe "#to_state with introduction" do
    before do
      allow(adapter).to receive(:chat).and_return('{"filing_status": "single"}')
      engine.submit_introduction("I am single", llm_client: llm_client)
    end

    subject(:state) { engine.to_state }

    it "includes introduction_text" do
      expect(state[:introduction_text]).to eq("I am single")
    end

    it "includes pre-filled answers" do
      expect(state[:answers][:filing_status]).to eq("single")
    end
  end

  describe ".from_state with introduction" do
    let(:state) do
      {
        current_step_id: :income_types,
        answers: { filing_status: "single", dependents: 0 },
        history: %i[filing_status dependents income_types],
        introduction_text: "I am single no dependents"
      }
    end

    subject(:restored) { described_class.from_state(definition, state) }

    its(:current_step_id) { is_expected.to eq(:income_types) }
    its(:introduction_text) { is_expected.to eq("I am single no dependents") }

    it "preserves pre-filled answers" do
      expect(restored.answers[:filing_status]).to eq("single")
      expect(restored.answers[:dependents]).to eq(0)
    end
  end
end
