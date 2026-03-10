# frozen_string_literal: true

require_relative "llm/adapter"
require_relative "llm/openai_adapter"
require_relative "llm/sensitive_data_filter"
require_relative "llm/system_prompt_builder"
require_relative "llm/client"

module FlowEngine
  # Namespace for LLM integration: adapters, system prompt building,
  # sensitive data filtering, and the high-level Client.
  module LLM
  end
end
