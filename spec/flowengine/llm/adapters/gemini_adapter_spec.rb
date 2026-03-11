# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::Adapters::GeminiAdapter do
  describe "class methods" do
    describe ".api_key_var_name" do
      subject { described_class.api_key_var_name }

      it { is_expected.to eq("GEMINI_API_KEY") }
    end

    describe ".default_model" do
      subject { described_class.default_model }

      it { is_expected.to eq("gemini-2.5-flash") }
    end

    describe ".provider" do
      subject { described_class.provider }

      it { is_expected.to eq(:gemini) }
    end
  end

  describe "instantiation" do
    context "with explicit API key" do
      subject(:adapter) { described_class.new(api_key: "AIza-test-key") }

      it { is_expected.to be_a(described_class) }
      it { is_expected.to be_a(FlowEngine::LLM::Adapter) }
      it { is_expected.to be_frozen }
      its(:api_key) { is_expected.to eq("AIza-test-key") }
      its(:model) { is_expected.to eq("gemini-2.5-flash") }
      its(:vendor) { is_expected.to eq(:gemini) }
      its(:qualifier) { is_expected.to eq(:default) }
    end

    context "with custom model and qualifier" do
      subject(:adapter) do
        described_class.new(api_key: "AIza-test-key", model: "gemini-2.5-pro", qualifier: :top)
      end

      its(:model) { is_expected.to eq("gemini-2.5-pro") }
      its(:qualifier) { is_expected.to eq(:top) }
    end

    context "with GEMINI_API_KEY env var" do
      around do |example|
        original = ENV.fetch("GEMINI_API_KEY", nil)
        ENV["GEMINI_API_KEY"] = "AIza-env-key"
        example.run
        if original
          ENV["GEMINI_API_KEY"] = original
        else
          ENV.delete("GEMINI_API_KEY")
        end
      end

      subject(:adapter) { described_class.new }

      it { is_expected.to be_a(described_class) }
      its(:api_key) { is_expected.to eq("AIza-env-key") }
    end

    context "without any API key" do
      around do |example|
        original = ENV.fetch("GEMINI_API_KEY", nil)
        ENV.delete("GEMINI_API_KEY")
        example.run
        ENV["GEMINI_API_KEY"] = original if original
      end

      it "raises NoAPIKeyFoundError" do
        expect { described_class.new }.to raise_error(
          FlowEngine::Errors::NoAPIKeyFoundError,
          /gemini API key not available/i
        )
      end
    end
  end
end
