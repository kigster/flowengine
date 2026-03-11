# frozen_string_literal: true

require "ruby_llm"

module FlowEngine
  module LLM
    # Abstract adapter for LLM API calls. Subclass and implement the class methods
    # {.api_key_var_name} and {.default_model} to integrate with a specific provider.
    # Thread-safe: RubyLLM configuration is protected by a mutex.
    class Adapter
      CONFIGURE_MUTEX = Mutex.new

      attr_reader :api_key, :model, :qualifier, :vendor

      # @param api_key [String, nil] API key; falls back to env var from {.api_key_var_name}
      # @param model [String, nil] model identifier; falls back to {.default_model}
      # @param qualifier [Symbol] adapter qualifier (:top, :default, :fastest)
      # @raise [Errors::NoAPIKeyFoundError] if no API key is available
      def initialize(api_key: nil, model: nil, qualifier: :default)
        @qualifier = qualifier
        @api_key = api_key || ENV.fetch(self.class.api_key_var_name, nil)
        @model = model || self.class.default_model
        @vendor = self.class.provider

        unless @api_key
          raise ::FlowEngine::Errors::NoAPIKeyFoundError,
                "#{vendor} API key not available ($#{self.class.api_key_var_name} not set)"
        end

        configure_ruby_llm!
        freeze
      end

      # Sends a system + user prompt pair to the LLM and returns the response text.
      #
      # @param system_prompt [String] system instructions for the LLM
      # @param user_prompt [String] user's text
      # @param model [String] model identifier (defaults to the adapter's model)
      # @return [String] the LLM's response content
      def chat(system_prompt:, user_prompt:, model: @model)
        conversation = RubyLLM.chat(model: model)
        response = conversation.with_instructions(system_prompt).ask(user_prompt)
        response.content
      end

      # Derives the provider symbol from the class name.
      # e.g. AnthropicAdapter => :anthropic, OpenAIAdapter => :openai
      #
      # @return [Symbol]
      def self.provider
        name.split("::").last.downcase.gsub("adapter", "").to_sym
      end

      # @return [String] name of the environment variable for this provider's API key
      def self.api_key_var_name
        raise NotImplementedError, "#{name}.api_key_var_name must be implemented"
      end

      # @return [String] default model identifier for this provider
      def self.default_model
        raise NotImplementedError, "#{name}.default_model must be implemented"
      end

      def inspect
        "#<#{self.class.name} vendor=#{vendor} model=#{model} qualifier=#{qualifier}>"
      end

      alias to_s inspect

      private

      def configure_ruby_llm!
        method_name = "#{vendor}_api_key="
        key = api_key
        CONFIGURE_MUTEX.synchronize do
          RubyLLM.configure { |config| config.send(method_name, key) }
        end
      end
    end
  end
end
