# frozen_string_literal: true

require_relative "llm/adapter"
require_relative "llm/openai_adapter"
require_relative "llm/anthropic_adapter"
require_relative "llm/gemini_adapter"
require_relative "llm/sensitive_data_filter"
require_relative "llm/system_prompt_builder"
require_relative "llm/client"

module FlowEngine
  # Namespace for LLM integration: adapters, system prompt building,
  # sensitive data filtering, and the high-level Client.
  module LLM
    # Provider registry: ordered by priority (first match wins).
    # Each entry maps an explicit kwarg name to [env_var, adapter_class, default_model].
    PROVIDERS = [
      [:anthropic_api_key, "ANTHROPIC_API_KEY", AnthropicAdapter, AnthropicAdapter::DEFAULT_MODEL],
      [:openai_api_key, "OPENAI_API_KEY", OpenAIAdapter, "gpt-4o-mini"],
      [:gemini_api_key, "GEMINI_API_KEY", GeminiAdapter, GeminiAdapter::DEFAULT_MODEL]
    ].freeze

    # Builds an adapter and Client by detecting which API key is available
    # in the environment. Priority: Anthropic > OpenAI > Gemini.
    #
    # @param anthropic_api_key [String, nil] explicit Anthropic key
    # @param openai_api_key [String, nil] explicit OpenAI key
    # @param gemini_api_key [String, nil] explicit Gemini key
    # @param model [String, nil] override model; auto-selected if nil
    # @return [Client] configured client with the detected adapter
    # @raise [LLMError] if no API key is found for any provider
    def self.auto_client(anthropic_api_key: nil, openai_api_key: nil, gemini_api_key: nil, model: nil)
      explicit_keys = { anthropic_api_key: anthropic_api_key, openai_api_key: openai_api_key,
                        gemini_api_key: gemini_api_key }

      PROVIDERS.each do |kwarg, env_var, adapter_class, default_model|
        key = explicit_keys[kwarg] || ENV.fetch(env_var, nil)
        next unless key

        adapter = adapter_class.new(api_key: key)
        return Client.new(adapter: adapter, model: model || default_model)
      end

      env_vars = PROVIDERS.map { |_, env_var, _, _| env_var }.join(", ")
      raise FlowEngine::LLMError, "No LLM API key found. Set #{env_vars}"
    end
  end
end
