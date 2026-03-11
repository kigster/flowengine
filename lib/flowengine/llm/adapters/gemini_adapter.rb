# frozen_string_literal: true

module FlowEngine
  module LLM
    module Adapters
      class GeminiAdapter < Adapter
        def self.api_key_var_name
          "GEMINI_API_KEY"
        end

        def self.default_model
          "gemini-2.5-flash"
        end
      end
    end
  end
end
