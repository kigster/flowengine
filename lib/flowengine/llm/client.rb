# frozen_string_literal: true

require "json"

module FlowEngine
  module LLM
    # High-level LLM client that parses introduction text into pre-filled answers.
    # Wraps an {Adapter} and a model name, builds the system prompt from the
    # flow Definition, and parses the structured JSON response.
    class Client
      attr_reader :adapter, :model

      # @param adapter [Adapter] LLM provider adapter (e.g. Adapters::OpenAIAdapter)
      # @param model [String, nil] model identifier; defaults to the adapter's model
      def initialize(adapter:, model: nil)
        @adapter = adapter
        @model = model || adapter.model
      end

      # Sends the introduction text to the LLM with a system prompt built from
      # the Definition, and returns a hash of extracted step answers.
      #
      # @param definition [Definition] flow definition (used to build system prompt)
      # @param introduction_text [String] user's free-form introduction
      # @return [Hash<Symbol, Object>] step_id => extracted value
      # @raise [Errors::LLMError] on response parsing failures
      def parse_introduction(definition:, introduction_text:)
        system_prompt = SystemPromptBuilder.new(definition).build
        response_text = adapter.chat(
          system_prompt: system_prompt,
          user_prompt: introduction_text,
          model: model
        )
        parse_response(response_text, definition)
      end

      def to_s
        "#<#{self.class.name} adapter=#{adapter} model=#{model}>"
      end

      private

      def parse_response(text, definition)
        json_str = extract_json(text)
        raw = JSON.parse(json_str, symbolize_names: true)

        raw.each_with_object({}) do |(step_id, value), result|
          next unless definition.steps.key?(step_id)

          node = definition.step(step_id)
          result[step_id] = coerce_value(value, node.type)
        end
      rescue JSON::ParserError => e
        raise ::FlowEngine::Errors::LLMError, "Failed to parse LLM response as JSON: #{e.message}"
      end

      def extract_json(text)
        # LLM may wrap JSON in markdown code fences
        match = text.match(/```(?:json)?\s*\n?(.*?)\n?\s*```/m)
        match ? match[1].strip : text.strip
      end

      def coerce_value(value, type)
        case type
        when :number
          value.is_a?(Numeric) ? value : value.to_i
        when :multi_select
          Array(value)
        when :number_matrix
          return {} unless value.is_a?(Hash)

          value.transform_values { |v| v.is_a?(Numeric) ? v : v.to_i }
        else
          value
        end
      end
    end
  end
end
