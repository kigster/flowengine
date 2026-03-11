# frozen_string_literal: true

module FlowEngine
  module LLM
    # Adapter classes are dynamically generated from resources/models.yml.
    # Each vendor entry produces a subclass of {Adapter} with the correct
    # api_key_var_name and default_model. Adding a new LLM provider is just
    # a YAML entry — no Ruby file needed.
    module Adapters
      LLM::VENDOR_CONFIG.each_value do |properties|
        class_name = properties["adapter"].split("::").last
        env_var = properties["var"]
        default = properties["default"]

        klass = Class.new(Adapter) do
          define_singleton_method(:api_key_var_name) { env_var }
          define_singleton_method(:default_model) { default }
        end

        const_set(class_name, klass)
      end
    end
  end
end
