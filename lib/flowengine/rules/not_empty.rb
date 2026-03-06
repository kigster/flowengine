# frozen_string_literal: true

module FlowEngine
  module Rules
    # Rule: the answer for the given field is present and not empty (nil or empty? => false).
    #
    # @attr_reader field [Symbol] answer key
    class NotEmpty < Base
      attr_reader :field

      # @param field [Symbol] answer key
      def initialize(field)
        super()
        @field = field
        freeze
      end

      # @param answers [Hash] current answers
      # @return [Boolean] false if nil or empty, true otherwise
      def evaluate(answers)
        val = answers[field]
        return false if val.nil?
        return false if val.respond_to?(:empty?) && val.empty?

        true
      end

      # @return [String] e.g. "name is not empty"
      def to_s
        "#{field} is not empty"
      end
    end
  end
end
