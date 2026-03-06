# frozen_string_literal: true

module FlowEngine
  # A single edge from one step to another, optionally guarded by a rule.
  # Transitions are evaluated in order; the first whose rule is true determines the next step.
  #
  # @attr_reader target [Symbol] id of the step to go to when this transition applies
  # @attr_reader rule [Rules::Base, nil] condition; nil means unconditional (always applies)
  class Transition
    attr_reader :target, :rule

    # @param target [Symbol] next step id
    # @param rule [Rules::Base, nil] optional condition (nil = always)
    def initialize(target:, rule: nil)
      @target = target
      @rule = rule
      freeze
    end

    # Human-readable label for the condition (e.g. for graph export).
    #
    # @return [String] rule#to_s or "always" when rule is nil
    def condition_label
      rule ? rule.to_s : "always"
    end

    # Whether this transition should be taken given current answers.
    #
    # @param answers [Hash] current answer state
    # @return [Boolean] true if rule is nil or rule evaluates to true
    def applies?(answers)
      return true if rule.nil?

      rule.evaluate(answers)
    end
  end
end
