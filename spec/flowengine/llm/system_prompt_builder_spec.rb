# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::SystemPromptBuilder do
  let(:definition) do
    FlowEngine.define do
      start :name

      step :name do
        type :text
        question "What is your name?"
        transition to: :age
      end

      step :age do
        type :number
        question "How old are you?"
        transition to: :hobbies
      end

      step :hobbies do
        type :multi_select
        question "Select your hobbies"
        options %w[Reading Cooking Gaming]
      end
    end
  end

  subject(:builder) { described_class.new(definition) }

  describe "#build" do
    subject(:prompt) { builder.build }

    it { is_expected.to be_a(String) }

    it "includes the static template content" do
      expect(prompt).to include("generic intake assistant")
    end

    it "includes step descriptions" do
      expect(prompt).to include("Step: `name`")
      expect(prompt).to include("Step: `age`")
      expect(prompt).to include("Step: `hobbies`")
    end

    it "includes step types" do
      expect(prompt).to include("**Type**: text")
      expect(prompt).to include("**Type**: number")
      expect(prompt).to include("**Type**: multi_select")
    end

    it "includes step questions" do
      expect(prompt).to include("What is your name?")
      expect(prompt).to include("How old are you?")
      expect(prompt).to include("Select your hobbies")
    end

    it "includes options for multi_select steps" do
      expect(prompt).to include("Reading, Cooking, Gaming")
    end

    it "includes response format instructions" do
      expect(prompt).to include("JSON object")
      expect(prompt).to include("single_select")
      expect(prompt).to include("multi_select")
    end
  end

  context "with hash options (key => label)" do
    let(:definition) do
      FlowEngine.define do
        start :status

        step :status do
          type :single_select
          question "Filing status?"
          options({ "single" => "Single", "mfj" => "Married Filing Jointly" })
        end
      end
    end

    subject(:prompt) { builder.build }

    it "includes both keys and labels" do
      expect(prompt).to include("single (Single)")
      expect(prompt).to include("mfj (Married Filing Jointly)")
    end

    it "instructs the LLM to use keys" do
      expect(prompt).to include("Use the option keys")
    end
  end
end
