# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::Adapter do
  subject(:adapter) { described_class.new }

  describe "#chat" do
    it "raises NotImplementedError" do
      expect { adapter.chat(system_prompt: "hi", user_prompt: "hello", model: "test") }
        .to raise_error(NotImplementedError, /chat must be implemented/)
    end
  end
end
