# frozen_string_literal: true

module FlowEngine
  module LLM
    # Immutable data class representing an LLM provider configuration.
    Provider = Data.define(:name, :env_var, :adapter_class) do
      def available?
        !ENV.fetch(env_var, nil).nil?
      end
    end
  end
end
