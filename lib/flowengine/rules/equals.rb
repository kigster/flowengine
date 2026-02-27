# frozen_string_literal: true

module FlowEngine
  module Rules
    class Equals < Base
      attr_reader :field, :value

      def initialize(field, value)
        super()
        @field = field
        @value = value
        freeze
      end

      def evaluate(answers)
        answers[field] == value
      end

      def to_s
        "#{field} == #{value}"
      end
    end
  end
end
