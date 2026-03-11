# frozen_string_literal: true

RSpec.describe FlowEngine::LLM, ".auto_client" do
  # Save and restore all env vars around every example
  around do |example|
    saved = {
      "ANTHROPIC_API_KEY" => ENV.fetch("ANTHROPIC_API_KEY", nil),
      "OPENAI_API_KEY" => ENV.fetch("OPENAI_API_KEY", nil),
      "GEMINI_API_KEY" => ENV.fetch("GEMINI_API_KEY", nil)
    }
    example.run
  ensure
    saved.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end

  def clear_all_keys
    ENV.delete("ANTHROPIC_API_KEY")
    ENV.delete("OPENAI_API_KEY")
    ENV.delete("GEMINI_API_KEY")
  end

  context "when ANTHROPIC_API_KEY is set" do
    before do
      clear_all_keys
      ENV["ANTHROPIC_API_KEY"] = "sk-ant-test"
    end

    subject(:client) { described_class.auto_client }

    its(:adapter) do
      is_expected.to be_a(FlowEngine::LLM::Adapters::AnthropicAdapter)
    end
    its(:model) { is_expected.to eq("claude-sonnet-4-6") }
  end

  context "when only OPENAI_API_KEY is set" do
    before do
      clear_all_keys
      ENV["OPENAI_API_KEY"] = "sk-openai-test"
    end

    subject(:client) { described_class.auto_client }

    its(:adapter) do
      is_expected.to be_a(FlowEngine::LLM::Adapters::OpenAIAdapter)
    end
    its(:model) { is_expected.to eq("gpt-5-mini") }
  end

  context "when only GEMINI_API_KEY is set" do
    before do
      clear_all_keys
      ENV["GEMINI_API_KEY"] = "AIza-test"
    end

    subject(:client) { described_class.auto_client }

    its(:adapter) do
      is_expected.to be_a(FlowEngine::LLM::Adapters::GeminiAdapter)
    end
    its(:model) { is_expected.to eq("gemini-2.5-flash") }
  end

  context "when all three keys are set" do
    before do
      ENV["ANTHROPIC_API_KEY"] = "sk-ant-test"
      ENV["OPENAI_API_KEY"] = "sk-openai-test"
      ENV["GEMINI_API_KEY"] = "AIza-test"
    end

    subject(:client) { described_class.auto_client }

    it "prefers Anthropic" do
      expect(client.adapter).to be_a(
        FlowEngine::LLM::Adapters::AnthropicAdapter
      )
    end
  end

  context "when only OpenAI and Gemini keys are set" do
    before do
      clear_all_keys
      ENV["OPENAI_API_KEY"] = "sk-openai-test"
      ENV["GEMINI_API_KEY"] = "AIza-test"
    end

    subject(:client) { described_class.auto_client }

    it "prefers OpenAI over Gemini" do
      expect(client.adapter).to be_a(FlowEngine::LLM::Adapters::OpenAIAdapter)
    end
  end

  context "when explicit keys override env" do
    before { clear_all_keys }

    it "uses explicit anthropic key" do
      client = described_class.auto_client(anthropic_api_key: "sk-ant-explicit")
      expect(client.adapter).to be_a(
        FlowEngine::LLM::Adapters::AnthropicAdapter
      )
    end

    it "uses explicit openai key" do
      client = described_class.auto_client(openai_api_key: "sk-openai-explicit")
      expect(client.adapter).to be_a(FlowEngine::LLM::Adapters::OpenAIAdapter)
    end

    it "uses explicit gemini key" do
      client = described_class.auto_client(gemini_api_key: "AIza-explicit")
      expect(client.adapter).to be_a(FlowEngine::LLM::Adapters::GeminiAdapter)
    end
  end

  context "when a model override is provided" do
    before do
      clear_all_keys
      ENV["ANTHROPIC_API_KEY"] = "sk-ant-test"
    end

    subject(:client) do
      described_class.auto_client(model: "claude-haiku-4-5-20251001")
    end

    its(:model) { is_expected.to eq("claude-haiku-4-5-20251001") }
  end

  context "when no API key is available" do
    before { clear_all_keys }

    it "raises LLMError" do
      expect { described_class.auto_client }.to raise_error(
        FlowEngine::Errors::LLMError,
        /No LLM API key found/
      )
    end
  end
end
