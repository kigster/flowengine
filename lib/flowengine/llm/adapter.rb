# frozen_string_literal: true

module FlowEngine
  module LLM
    # Abstract adapter for LLM API calls. Subclass and implement {#chat}
    # to integrate with a specific provider (OpenAI, Anthropic, etc.).
    class Adapter
      # Sends a system + user prompt pair to the LLM and returns the response text.
      #
      # @param system_prompt [String] system instructions for the LLM
      # @param user_prompt [String] user's introduction text
      # @param model [String] model identifier (e.g. "gpt-4o-mini")
      # @return [String] the LLM's response text (expected to be JSON)
      def chat(system_prompt:, user_prompt:, model:)
        raise NotImplementedError, "#{self.class}#chat must be implemented"
      end
    end
  end
end
