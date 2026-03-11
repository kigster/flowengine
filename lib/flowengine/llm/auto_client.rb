# frozen_string_literal: true

module FlowEngine
  module LLM
    # Client that picks its adapter from the pre-loaded ADAPTERS registry.
    # Requires {LLM.load!} to have been called first.
    class AutoClient < Client
      # @param qualifier [Symbol] which model tier to use (:top, :default, :fastest)
      # @raise [Errors::LLMError] if no adapters have been loaded
      def initialize(qualifier: :default)
        raise ::FlowEngine::Errors::LLMError, "No adapters loaded. Call FlowEngine::LLM.load! first." if ADAPTERS.empty?

        entry = ADAPTERS.values.first
        adapter = entry[qualifier.to_s]
        super(adapter: adapter, model: adapter.model)
      end
    end
  end
end
