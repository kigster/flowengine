# frozen_string_literal: true

module FlowEngine
  class Evaluator
    attr_reader :answers

    def initialize(answers)
      @answers = answers
    end

    def evaluate(rule)
      return true if rule.nil?

      rule.evaluate(answers)
    end
  end
end
