# frozen_string_literal: true

module FlowEngine
  module Rules
    # Rule: the answer for the given field (coerced to integer) is less than the threshold.
    #
    # @attr_reader field [Symbol] answer key
    # @attr_reader value [Integer] threshold
    class LessThan < Base
      attr_reader :field, :value

      # @param field [Symbol] answer key
      # @param value [Integer] threshold
      def initialize(field, value)
        super()
        @field = field
        @value = value
        freeze
      end

      # @param answers [Hash] current answers (field value is coerced with to_i)
      # @return [Boolean] true if answers[field].to_i < value
      def evaluate(answers)
        answers[field].to_i < value
      end

      # @return [String] e.g. "age < 18"
      def to_s
        "#{field} < #{value}"
      end
    end
  end
end
