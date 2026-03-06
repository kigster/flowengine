# frozen_string_literal: true

module FlowEngine
  module Rules
    # Rule: the answer for the given field (as an array) includes the given value.
    # Used for multi-select steps (e.g. "BusinessOwnership in earnings").
    #
    # @attr_reader field [Symbol] answer key (step id)
    # @attr_reader value [Object] value that must be present in the array
    class Contains < Base
      attr_reader :field, :value

      # @param field [Symbol] answer key
      # @param value [Object] value to check for
      def initialize(field, value)
        super()
        @field = field
        @value = value
        freeze
      end

      # @param answers [Hash] current answers
      # @return [Boolean] true if answers[field] (as array) includes value
      def evaluate(answers)
        Array(answers[field]).include?(value)
      end

      # @return [String] e.g. "BusinessOwnership in earnings"
      def to_s
        "#{value} in #{field}"
      end
    end
  end
end
