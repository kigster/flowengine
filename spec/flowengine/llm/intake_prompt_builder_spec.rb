# frozen_string_literal: true

require "rspec"
require "rspec/its"

RSpec.describe FlowEngine::LLM::IntakePromptBuilder do
  let(:definition) do
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
        question "What is your filing status?"
        options %w[single married_joint]
        transition to: :dependents
      end

      step :dependents do
        type :number
        question "How many dependents?"
        transition to: :state_info
      end

      step :state_info do
        type :text
        question "Which state do you live in?"
      end
    end
  end

  describe "#build" do
    context "with no answered steps" do
      subject(:prompt) { described_class.new(definition).build }

      it { is_expected.to be_a(String) }
      it { is_expected.to include("filing_status") }
      it { is_expected.to include("dependents") }
      it { is_expected.to include("state_info") }
      it { is_expected.not_to include("Already Answered") }
      it { is_expected.to include("follow_up") }
      it { is_expected.to include("Unanswered Steps") }

      it "excludes ai_intake steps from unanswered list" do
        expect(subject).not_to match(/### Step: `intake`/)
      end
    end

    context "with some answered steps" do
      subject(:prompt) do
        described_class.new(
          definition,
          answered: { filing_status: "single" }
        ).build
      end

      it { is_expected.to include("Already Answered") }
      it { is_expected.to include("filing_status") }
      it { is_expected.to include("`\"single\"`") }

      it "still lists unanswered steps" do
        expect(subject).to include("dependents")
        expect(subject).to include("state_info")
      end
    end

    context "with conversation history" do
      subject(:prompt) do
        described_class.new(
          definition,
          answered: { filing_status: "single" },
          conversation_history: [
            { role: :user, text: "I'm single" },
            { role: :assistant, text: "How many dependents?" }
          ]
        ).build
      end

      it { is_expected.to include("Conversation History") }
      it { is_expected.to include("I'm single") }
      it { is_expected.to include("How many dependents?") }
    end

    context "with options on steps" do
      subject(:prompt) { described_class.new(definition).build }

      it "includes options for select steps" do
        expect(subject).to include("single")
        expect(subject).to include("married_joint")
      end
    end

    context "with hash options" do
      let(:definition) do
        FlowEngine.define do
          start :intake

          step :intake do
            type :ai_intake
            question "Tell us"
            max_clarifications 1
            transition to: :status
          end

          step :status do
            type :single_select
            question "Status?"
            options({ single: "Single", mfj: "Married Filing Jointly" })
          end
        end
      end

      subject(:prompt) { described_class.new(definition).build }

      it "includes both keys and labels" do
        expect(subject).to include("single")
        expect(subject).to include("Single")
        expect(subject).to include("Use the option keys")
      end
    end

    context "response format" do
      subject(:prompt) { described_class.new(definition).build }

      it "instructs JSON with answers and follow_up keys" do
        expect(subject).to include('"answers"')
        expect(subject).to include('"follow_up"')
      end
    end
  end
end
