# frozen_string_literal: true

module FlowEngine
  # A single step in the flow: question metadata, input config, and conditional transitions.
  # Used by {Engine} to determine the next step and by UI/export to render the step.
  #
  # @attr_reader id [Symbol] unique step identifier
  # @attr_reader type [Symbol] input type (e.g. :multi_select, :number_matrix)
  # @attr_reader question [String] prompt text for the step
  # @attr_reader options [Array, nil] choices for multi_select; nil for other types
  # @attr_reader fields [Array, nil] field names for number_matrix etc.; nil otherwise
  # @attr_reader transitions [Array<Transition>] ordered list of conditional next-step rules
  # @attr_reader visibility_rule [Rules::Base, nil] rule controlling whether this node is visible (DAG mode)
  class Node
    attr_reader :id, :type, :question, :options, :fields, :transitions, :visibility_rule

    # @param id [Symbol] step id
    # @param type [Symbol] step/input type
    # @param question [String] label/prompt
    # @param decorations [Object, nil] optional UI decorations (not used by engine)
    # @param options [Array, nil] option list for multi_select
    # @param fields [Array, nil] field list for matrix-style steps
    # @param transitions [Array<Transition>] conditional next-step transitions (default: [])
    # @param visibility_rule [Rules::Base, nil] optional rule for visibility (default: always visible)
    def initialize(id:, # rubocop:disable Metrics/ParameterLists
                   type:,
                   question:,
                   decorations: nil,
                   options: nil,
                   fields: nil,
                   transitions: [],
                   visibility_rule: nil)
      @id = id
      @type = type
      @question = question
      @decorations = decorations
      @options = options&.freeze
      @fields = fields&.freeze
      @transitions = transitions.freeze
      @visibility_rule = visibility_rule
      freeze
    end

    # Resolves the next step id from current answers by evaluating transitions in order.
    #
    # @param answers [Hash] current answer state (step_id => value)
    # @return [Symbol, nil] id of the next step, or nil if no transition matches (flow end)
    def next_step_id(answers)
      match = transitions.find { |t| t.applies?(answers) }
      match&.target
    end

    # Whether this node should be considered visible given current answers (for DAG/visibility).
    #
    # @param answers [Hash] current answer state
    # @return [Boolean] true if no visibility_rule, else result of rule evaluation
    def visible?(answers)
      return true if visibility_rule.nil?

      visibility_rule.evaluate(answers)
    end
  end
end
