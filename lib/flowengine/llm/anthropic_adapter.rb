# frozen_string_literal: true

require "ruby_llm"

module FlowEngine
  module LLM
    # Anthropic adapter using the ruby_llm gem. Configures the API key
    # and delegates chat calls to RubyLLM's conversation interface.
    class AnthropicAdapter < Adapter
      DEFAULT_MODEL = "claude-sonnet-4-20250514"

      # @param api_key [String, nil] Anthropic API key; falls back to ANTHROPIC_API_KEY env var
      # @raise [LLMError] if no API key is available
      def initialize(api_key: nil)
        super()
        @api_key = api_key || ENV.fetch("ANTHROPIC_API_KEY", nil)
        raise LLMError, "Anthropic API key not provided and ANTHROPIC_API_KEY not set" unless @api_key
      end

      # @param system_prompt [String] system instructions
      # @param user_prompt [String] user's text
      # @param model [String] Anthropic model identifier
      # @return [String] response content from the LLM
      def chat(system_prompt:, user_prompt:, model: DEFAULT_MODEL)
        configure_ruby_llm!
        conversation = RubyLLM.chat(model: model)
        response = conversation.with_instructions(system_prompt).ask(user_prompt)
        response.content
      end

      private

      def configure_ruby_llm!
        RubyLLM.configure do |config|
          config.anthropic_api_key = @api_key
        end
      end
    end
  end
end
