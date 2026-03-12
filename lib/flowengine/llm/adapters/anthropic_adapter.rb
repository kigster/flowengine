# frozen_string_literal: true

module FlowEngine
  module LLM
    module Adapters
      class AnthropicAdapter < Adapter
        def self.api_key_var_name
          "ANTHROPIC_API_KEY"
        end

        def self.default_model
          "claude-sonnet-4-6"
        end
      end
    end
  end
end
