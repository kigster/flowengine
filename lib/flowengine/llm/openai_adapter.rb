# frozen_string_literal: true

require "ruby_llm"

module FlowEngine
  module LLM
    # OpenAI adapter using the ruby_llm gem. Configures the API key
    # and delegates chat calls to RubyLLM's conversation interface.
    class OpenAIAdapter < Adapter
      # @param api_key [String, nil] OpenAI API key; falls back to OPENAI_API_KEY env var
      # @raise [LLMError] if no API key is available
      def initialize(api_key: nil)
        super()
        @api_key = api_key || ENV.fetch("OPENAI_API_KEY", nil)
        raise LLMError, "OpenAI API key not provided and OPENAI_API_KEY not set" unless @api_key
      end

      # @param system_prompt [String] system instructions
      # @param user_prompt [String] user's text
      # @param model [String] OpenAI model identifier
      # @return [String] response content from the LLM
      def chat(system_prompt:, user_prompt:, model: "gpt-4o-mini")
        configure_ruby_llm!
        conversation = RubyLLM.chat(model: model)
        response = conversation.with_instructions(system_prompt).ask(user_prompt)
        response.content
      end

      private

      def configure_ruby_llm!
        RubyLLM.configure do |config|
          config.openai_api_key = @api_key
        end
      end
    end
  end
end
