# frozen_string_literal: true

module FlowEngine
  class Transition
    attr_reader :target, :rule

    def initialize(target:, rule: nil)
      @target = target
      @rule = rule
      freeze
    end

    def condition_label
      rule ? rule.to_s : "always"
    end

    def applies?(answers)
      return true if rule.nil?

      rule.evaluate(answers)
    end
  end
end
