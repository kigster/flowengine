# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::AnthropicAdapter do
  describe ".new" do
    context "with explicit API key" do
      subject(:adapter) { described_class.new(api_key: "sk-ant-test-key") }

      it { is_expected.to be_a(FlowEngine::LLM::Adapter) }
    end

    context "with ANTHROPIC_API_KEY env var" do
      around do |example|
        original = ENV.fetch("ANTHROPIC_API_KEY", nil)
        ENV["ANTHROPIC_API_KEY"] = "sk-ant-env-key"
        example.run
        original ? ENV["ANTHROPIC_API_KEY"] = original : ENV.delete("ANTHROPIC_API_KEY")
      end

      subject(:adapter) { described_class.new }

      it { is_expected.to be_a(FlowEngine::LLM::Adapter) }
    end

    context "without any API key" do
      around do |example|
        original = ENV.fetch("ANTHROPIC_API_KEY", nil)
        ENV.delete("ANTHROPIC_API_KEY")
        example.run
        ENV["ANTHROPIC_API_KEY"] = original if original
      end

      it "raises LLMError" do
        expect { described_class.new }.to raise_error(FlowEngine::LLMError, /API key/)
      end
    end
  end

  describe "#chat" do
    subject(:adapter) { described_class.new(api_key: "sk-ant-test-key") }

    let(:mock_response) { instance_double("RubyLLM::Response", content: '{"filing_status": "married"}') }
    let(:mock_chat) { instance_double("RubyLLM::Chat") }

    before do
      allow(RubyLLM).to receive(:configure).and_yield(double("config", anthropic_api_key: nil).as_null_object)
      allow(RubyLLM).to receive(:chat).and_return(mock_chat)
      allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
      allow(mock_chat).to receive(:ask).and_return(mock_response)
    end

    it "returns the LLM response content" do
      result = adapter.chat(system_prompt: "system", user_prompt: "user")
      expect(result).to eq('{"filing_status": "married"}')
    end

    it "uses the default Anthropic model" do
      adapter.chat(system_prompt: "system", user_prompt: "user")
      expect(RubyLLM).to have_received(:chat).with(model: "claude-sonnet-4-20250514")
    end

    it "passes the system prompt as instructions" do
      adapter.chat(system_prompt: "Be helpful", user_prompt: "Hello")
      expect(mock_chat).to have_received(:with_instructions).with("Be helpful")
    end

    it "passes the user prompt as the question" do
      adapter.chat(system_prompt: "system", user_prompt: "I am married with 2 kids")
      expect(mock_chat).to have_received(:ask).with("I am married with 2 kids")
    end

    it "accepts a custom model" do
      adapter.chat(system_prompt: "system", user_prompt: "user", model: "claude-haiku-4-5-20251001")
      expect(RubyLLM).to have_received(:chat).with(model: "claude-haiku-4-5-20251001")
    end
  end
end
