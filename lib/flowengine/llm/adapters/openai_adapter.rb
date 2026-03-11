# frozen_string_literal: true

module FlowEngine
  module LLM
    module Adapters
      class OpenAIAdapter < Adapter
        def self.api_key_var_name
          "OPENAI_API_KEY"
        end

        def self.default_model
          "gpt-5-mini"
        end
      end
    end
  end
end
