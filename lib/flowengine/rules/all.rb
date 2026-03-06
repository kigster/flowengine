# frozen_string_literal: true

module FlowEngine
  module Rules
    # Composite rule: logical AND of multiple sub-rules. All must be true.
    #
    # @attr_reader rules [Array<Base>] sub-rules to evaluate
    class All < Base
      attr_reader :rules

      # @param rules [Array<Base>] one or more rules (arrays are flattened)
      def initialize(*rules)
        super()
        @rules = rules.flatten.freeze
        freeze
      end

      # @param answers [Hash] current answers
      # @return [Boolean] true if every sub-rule evaluates to true
      def evaluate(answers)
        rules.all? { |rule| rule.evaluate(answers) }
      end

      # @return [String] e.g. "(rule1 AND rule2 AND rule3)"
      def to_s
        "(#{rules.join(" AND ")})"
      end
    end
  end
end
