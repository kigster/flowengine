# frozen_string_literal: true

module FlowEngine
  module Rules
    class LessThan < Base
      attr_reader :field, :value

      def initialize(field, value)
        super()
        @field = field
        @value = value
        freeze
      end

      def evaluate(answers)
        answers[field].to_i < value
      end

      def to_s
        "#{field} < #{value}"
      end
    end
  end
end
