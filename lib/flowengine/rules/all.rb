# frozen_string_literal: true

module FlowEngine
  module Rules
    class All < Base
      attr_reader :rules

      def initialize(*rules)
        super()
        @rules = rules.flatten.freeze
        freeze
      end

      def evaluate(answers)
        rules.all? { |rule| rule.evaluate(answers) }
      end

      def to_s
        "(#{rules.join(" AND ")})"
      end
    end
  end
end
