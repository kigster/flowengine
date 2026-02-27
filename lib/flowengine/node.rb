# frozen_string_literal: true

module FlowEngine
  class Node
    attr_reader :id, :type, :question, :options, :fields, :transitions, :visibility_rule

    def initialize(id:, type:, question:, options: nil, fields: nil, transitions: [], visibility_rule: nil)
      @id = id
      @type = type
      @question = question
      @options = options&.freeze
      @fields = fields&.freeze
      @transitions = transitions.freeze
      @visibility_rule = visibility_rule
      freeze
    end

    def next_step_id(answers)
      match = transitions.find { |t| t.applies?(answers) }
      match&.target
    end

    def visible?(answers)
      return true if visibility_rule.nil?

      visibility_rule.evaluate(answers)
    end
  end
end
