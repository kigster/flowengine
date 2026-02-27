# frozen_string_literal: true

module FlowEngine
  module Rules
    class NotEmpty < Base
      attr_reader :field

      def initialize(field)
        super()
        @field = field
        freeze
      end

      def evaluate(answers)
        val = answers[field]
        return false if val.nil?
        return false if val.respond_to?(:empty?) && val.empty?

        true
      end

      def to_s
        "#{field} is not empty"
      end
    end
  end
end
