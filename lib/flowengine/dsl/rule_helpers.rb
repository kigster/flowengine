# frozen_string_literal: true

module FlowEngine
  module DSL
    # Factory methods for rule objects, included in {FlowBuilder} and {StepBuilder}.
    # Use these inside step blocks for transition conditions and visible_if.
    module RuleHelpers
      # @param field [Symbol] answer key (step id)
      # @param value [Object] value to check for in the array
      # @return [Rules::Contains]
      def contains(field, value)
        Rules::Contains.new(field, value)
      end

      # @param field [Symbol] answer key
      # @param value [Object] expected value
      # @return [Rules::Equals]
      def equals(field, value)
        Rules::Equals.new(field, value)
      end

      # @param field [Symbol] answer key (value coerced to integer for comparison)
      # @param value [Integer] threshold
      # @return [Rules::GreaterThan]
      def greater_than(field, value)
        Rules::GreaterThan.new(field, value)
      end

      # @param field [Symbol] answer key (value coerced to integer for comparison)
      # @param value [Integer] threshold
      # @return [Rules::LessThan]
      def less_than(field, value)
        Rules::LessThan.new(field, value)
      end

      # @param field [Symbol] answer key
      # @return [Rules::NotEmpty]
      def not_empty(field)
        Rules::NotEmpty.new(field)
      end

      # Logical AND of multiple rules.
      # @param rules [Array<Rules::Base>] rules to combine
      # @return [Rules::All]
      def all(*rules)
        Rules::All.new(*rules)
      end

      # Logical OR of multiple rules.
      # @param rules [Array<Rules::Base>] rules to combine
      # @return [Rules::Any]
      def any(*rules)
        Rules::Any.new(*rules)
      end
    end
  end
end
