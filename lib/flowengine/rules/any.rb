# frozen_string_literal: true

module FlowEngine
  module Rules
    # Composite rule: logical OR of multiple sub-rules. At least one must be true.
    #
    # @attr_reader rules [Array<Base>] sub-rules to evaluate
    class Any < Base
      attr_reader :rules

      # @param rules [Array<Base>] one or more rules (arrays are flattened)
      def initialize(*rules)
        super()
        @rules = rules.flatten.freeze
        freeze
      end

      # @param answers [Hash] current answers
      # @return [Boolean] true if any sub-rule evaluates to true
      def evaluate(answers)
        rules.any? { |rule| rule.evaluate(answers) }
      end

      # @return [String] e.g. "(rule1 OR rule2 OR rule3)"
      def to_s
        "(#{rules.join(" OR ")})"
      end
    end
  end
end
