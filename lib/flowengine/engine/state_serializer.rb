# frozen_string_literal: true

module FlowEngine
  class Engine
    # Handles state serialization and deserialization for Engine persistence.
    # Normalizes string-keyed hashes (from JSON) to symbol-keyed hashes.
    module StateSerializer
      SYMBOLIZERS = {
        current_step_id: ->(v) { v&.to_sym },
        active_intake_step_id: ->(v) { v&.to_sym },
        history: ->(v) { Array(v).map { |e| e&.to_sym } },
        answers: ->(v) { symbolize_answers(v) },
        conversation_history: ->(v) { symbolize_conversation_history(v) }
      }.freeze

      # Normalizes a state hash so step ids and history entries are symbols.
      def self.symbolize_state(hash)
        return hash unless hash.is_a?(Hash)

        hash.each_with_object({}) do |(key, value), result|
          sym_key = key.to_sym
          result[sym_key] = SYMBOLIZERS.fetch(sym_key, ->(v) { v }).call(value)
        end
      end

      # @param answers [Hash] answers map (keys may be strings)
      # @return [Hash] same map with symbol keys
      def self.symbolize_answers(answers)
        return {} unless answers.is_a?(Hash)

        answers.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      end

      # @param history [Array<Hash>] conversation history entries
      # @return [Array<Hash>] same entries with symbolized keys and role
      def self.symbolize_conversation_history(history)
        return [] unless history.is_a?(Array)

        history.map do |entry|
          next entry unless entry.is_a?(Hash)

          entry.each_with_object({}) do |(k, v), h|
            sym_key = k.to_sym
            h[sym_key] = sym_key == :role ? v.to_sym : v
          end
        end
      end
    end
  end
end
