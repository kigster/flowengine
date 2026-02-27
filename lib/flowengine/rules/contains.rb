# frozen_string_literal: true

module FlowEngine
  module Rules
    class Contains < Base
      attr_reader :field, :value

      def initialize(field, value)
        super()
        @field = field
        @value = value
        freeze
      end

      def evaluate(answers)
        Array(answers[field]).include?(value)
      end

      def to_s
        "#{value} in #{field}"
      end
    end
  end
end
