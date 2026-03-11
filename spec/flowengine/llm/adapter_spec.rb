# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::Adapter do
  describe ".api_key_var_name" do
    it "raises NotImplementedError" do
      expect { described_class.api_key_var_name }
        .to raise_error(NotImplementedError, /api_key_var_name must be implemented/)
    end
  end

  describe ".default_model" do
    it "raises NotImplementedError" do
      expect { described_class.default_model }
        .to raise_error(NotImplementedError, /default_model must be implemented/)
    end
  end
end
