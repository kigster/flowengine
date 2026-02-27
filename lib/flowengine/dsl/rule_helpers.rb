# frozen_string_literal: true

module FlowEngine
  module DSL
    module RuleHelpers
      def contains(field, value)
        Rules::Contains.new(field, value)
      end

      def equals(field, value)
        Rules::Equals.new(field, value)
      end

      def greater_than(field, value)
        Rules::GreaterThan.new(field, value)
      end

      def less_than(field, value)
        Rules::LessThan.new(field, value)
      end

      def not_empty(field)
        Rules::NotEmpty.new(field)
      end

      def all(*rules)
        Rules::All.new(*rules)
      end

      def any(*rules)
        Rules::Any.new(*rules)
      end
    end
  end
end
