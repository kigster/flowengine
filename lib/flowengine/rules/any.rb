# frozen_string_literal: true

module FlowEngine
  module Rules
    class Any < Base
      attr_reader :rules

      def initialize(*rules)
        super()
        @rules = rules.flatten.freeze
        freeze
      end

      def evaluate(answers)
        rules.any? { |rule| rule.evaluate(answers) }
      end

      def to_s
        "(#{rules.join(" OR ")})"
      end
    end
  end
end
