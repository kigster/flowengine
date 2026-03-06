# frozen_string_literal: true

module FlowEngine
  module Rules
    # Rule: the answer for the given field equals the given value.
    #
    # @attr_reader field [Symbol] answer key
    # @attr_reader value [Object] expected value
    class Equals < Base
      attr_reader :field, :value

      # @param field [Symbol] answer key
      # @param value [Object] expected value
      def initialize(field, value)
        super()
        @field = field
        @value = value
        freeze
      end

      # @param answers [Hash] current answers
      # @return [Boolean] true if answers[field] == value
      def evaluate(answers)
        answers[field] == value
      end

      # @return [String] e.g. "marital_status == Married"
      def to_s
        "#{field} == #{value}"
      end
    end
  end
end
