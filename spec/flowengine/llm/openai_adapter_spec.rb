# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::Adapters::OpenAIAdapter do
  describe ".new" do
    context "with explicit API key" do
      subject(:adapter) { described_class.new(api_key: "sk-test-key") }

      it { is_expected.to be_a(FlowEngine::LLM::Adapter) }
    end

    context "with OPENAI_API_KEY env var" do
      around do |example|
        original = ENV.fetch("OPENAI_API_KEY", nil)
        ENV["OPENAI_API_KEY"] = "sk-env-key"
        example.run
        if original
          ENV["OPENAI_API_KEY"] = original
        else
          ENV.delete("OPENAI_API_KEY")
        end
      end

      subject(:adapter) { described_class.new }

      it { is_expected.to be_a(FlowEngine::LLM::Adapter) }
    end

    context "without any API key" do
      around do |example|
        original = ENV.fetch("OPENAI_API_KEY", nil)
        ENV.delete("OPENAI_API_KEY")
        example.run
        ENV["OPENAI_API_KEY"] = original if original
      end

      it "raises LLMError" do
        expect { described_class.new }.to raise_error(
          FlowEngine::Errors::LLMError,
          /API key/
        )
      end
    end
  end

  describe "#chat" do
    subject(:adapter) { described_class.new(api_key: "sk-test-key") }

    let(:mock_response) do
      instance_double(
        "RubyLLM::Response",
        content: '{"filing_status": "single"}'
      )
    end
    let(:mock_chat) { instance_double("RubyLLM::Chat") }

    before do
      allow(RubyLLM).to receive(:configure).and_yield(
        double("config", openai_api_key: nil).as_null_object
      )
      allow(RubyLLM).to receive(:chat).and_return(mock_chat)
      allow(mock_chat).to receive(:with_instructions).and_return(mock_chat)
      allow(mock_chat).to receive(:ask).and_return(mock_response)
    end

    it "returns the LLM response content" do
      result = adapter.chat(
        system_prompt: "system",
        user_prompt: "user",
        model: "gpt-5-mini"
      )
      expect(result).to eq('{"filing_status": "single"}')
    end

    it "passes the system prompt as instructions" do
      adapter.chat(
        system_prompt: "Be helpful",
        user_prompt: "Hello",
        model: "gpt-5-mini"
      )
      expect(mock_chat).to have_received(:with_instructions).with("Be helpful")
    end

    it "passes the user prompt as the question" do
      adapter.chat(
        system_prompt: "system",
        user_prompt: "I am single with no kids",
        model: "gpt-5-mini"
      )
      expect(mock_chat).to have_received(:ask).with("I am single with no kids")
    end
  end
end
