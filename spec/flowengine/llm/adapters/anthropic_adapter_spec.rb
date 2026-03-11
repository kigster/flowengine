# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::Adapters::AnthropicAdapter do
  describe "class methods" do
    describe ".api_key_var_name" do
      subject { described_class.api_key_var_name }

      it { is_expected.to eq("ANTHROPIC_API_KEY") }
    end

    describe ".default_model" do
      subject { described_class.default_model }

      it { is_expected.to eq("claude-sonnet-4-6") }
    end

    describe ".provider" do
      subject { described_class.provider }

      it { is_expected.to eq(:anthropic) }
    end
  end

  describe "instantiation" do
    context "with explicit API key" do
      subject(:adapter) { described_class.new(api_key: "sk-ant-test-key") }

      it { is_expected.to be_a(described_class) }
      it { is_expected.to be_a(FlowEngine::LLM::Adapter) }
      it { is_expected.to be_frozen }
      its(:api_key) { is_expected.to eq("sk-ant-test-key") }
      its(:model) { is_expected.to eq("claude-sonnet-4-6") }
      its(:vendor) { is_expected.to eq(:anthropic) }
      its(:qualifier) { is_expected.to eq(:default) }
    end

    context "with custom model and qualifier" do
      subject(:adapter) do
        described_class.new(api_key: "sk-ant-test-key", model: "claude-haiku-4-5-20251001", qualifier: :fastest)
      end

      its(:model) { is_expected.to eq("claude-haiku-4-5-20251001") }
      its(:qualifier) { is_expected.to eq(:fastest) }
    end

    context "with ANTHROPIC_API_KEY env var" do
      around do |example|
        original = ENV.fetch("ANTHROPIC_API_KEY", nil)
        ENV["ANTHROPIC_API_KEY"] = "sk-ant-env-key"
        example.run
        if original
          ENV["ANTHROPIC_API_KEY"] = original
        else
          ENV.delete("ANTHROPIC_API_KEY")
        end
      end

      subject(:adapter) { described_class.new }

      it { is_expected.to be_a(described_class) }
      its(:api_key) { is_expected.to eq("sk-ant-env-key") }
    end

    context "without any API key" do
      around do |example|
        original = ENV.fetch("ANTHROPIC_API_KEY", nil)
        ENV.delete("ANTHROPIC_API_KEY")
        example.run
        ENV["ANTHROPIC_API_KEY"] = original if original
      end

      it "raises NoAPIKeyFoundError" do
        expect { described_class.new }.to raise_error(
          FlowEngine::Errors::NoAPIKeyFoundError,
          /anthropic API key not available/i
        )
      end
    end
  end
end
