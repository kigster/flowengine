# frozen_string_literal: true

require "yaml"

module FlowEngine
  # Namespace for LLM integration: adapters, system prompt building,
  # sensitive data filtering, and the high-level Client.
  module LLM
    # Path to the models.yml file (overridable via env var)
    MODELS_YAML_PATH = ENV.fetch(
      "FLOWENGINE_LLM_MODELS_PATH",
      File.join(::FlowEngine::ROOT, "resources", "models.yml")
    )

    # Vendor config loaded once from models.yml — used by Adapters module
    # to dynamically generate adapter classes and by auto_client for detection.
    VENDOR_CONFIG = (YAML.load_file(MODELS_YAML_PATH).dig("models", "vendors") || {}).freeze

    # Provider priority for auto-detection: [kwarg_name, env_var, adapter_class_name]
    PROVIDERS = VENDOR_CONFIG.map do |_vendor, properties|
      [properties["var"].downcase.to_sym, properties["var"], properties["adapter"]]
    end.freeze

    # Pre-loaded adapters registry: { "vendor" => { "qualifier" => adapter } }
    ADAPTERS = {} # rubocop:disable Style/MutableConstant -- intentionally mutable registry
    ADAPTERS_MUTEX = Mutex.new
    QUALIFIERS = %i[top default fastest].freeze

    class << self
      # Builds an adapter and Client by detecting which API key is available.
      # Priority order matches models.yml vendor order (Anthropic > OpenAI > Gemini).
      #
      # @param anthropic_api_key [String, nil] explicit Anthropic key
      # @param openai_api_key [String, nil] explicit OpenAI key
      # @param gemini_api_key [String, nil] explicit Gemini key
      # @param model [String, nil] override model; adapter default if nil
      # @return [Client] configured client with the detected adapter
      # @raise [Errors::LLMError] if no API key is found for any provider
      def auto_client(anthropic_api_key: nil, openai_api_key: nil, gemini_api_key: nil, model: nil)
        explicit_keys = {
          anthropic_api_key: anthropic_api_key,
          openai_api_key: openai_api_key,
          gemini_api_key: gemini_api_key
        }

        PROVIDERS.each do |kwarg, env_var, adapter_class_name|
          key = explicit_keys[kwarg] || ENV.fetch(env_var, nil)
          next unless key

          adapter_class = ::FlowEngine.constantize(adapter_class_name)
          adapter = adapter_class.new(api_key: key)
          return Client.new(adapter: adapter, model: model || adapter.model)
        end

        env_vars = PROVIDERS.map { |_, env_var, _| env_var }.join(", ")
        raise ::FlowEngine::Errors::LLMError, "No LLM API key found. Set #{env_vars}"
      end

      # Pre-loads adapters from models.yml into ADAPTERS registry.
      # Call explicitly when you want pre-instantiated adapters (e.g. in bin/ask).
      def load!(file = MODELS_YAML_PATH)
        return if @adapters_loaded

        raise ::FlowEngine::Errors::ConfigurationError, "Models file #{file} not found" unless file && File.exist?(file)

        count = 0
        ::YAML.load_file(file)["models"]["vendors"].each_pair do |vendor, properties|
          api_key = ENV.fetch(properties["var"], nil)
          unless api_key
            warn "API key for #{vendor} not found in environment, vendor disabled."
            next
          end

          adapter_class = ::FlowEngine.constantize(properties["adapter"])
          QUALIFIERS.each do |qualifier|
            model = properties[qualifier.to_s]
            adapter = adapter_class.new(api_key: api_key, model: model, qualifier: qualifier)
            add_adapter(adapter)
            count += 1
          end
        end
        @adapters_loaded = true
        warn "Loaded #{count} adapters for #{ADAPTERS.keys.size} vendors."
      end

      # Looks up a pre-loaded adapter by vendor and qualifier.
      def [](vendor:, qualifier: :default)
        ADAPTERS.dig(vendor.to_s, qualifier.to_s)
      end

      # Resets the loaded state (useful for testing).
      def reset!
        ADAPTERS_MUTEX.synchronize { ADAPTERS.clear }
        @adapters_loaded = false
      end

      private

      def add_adapter(adapter)
        ADAPTERS_MUTEX.synchronize do
          ADAPTERS[adapter.vendor.to_s] ||= {}
          ADAPTERS[adapter.vendor.to_s][adapter.qualifier.to_s] = adapter
        end
      end
    end
  end
end
