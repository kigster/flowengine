# frozen_string_literal: true

module FlowEngine
  module DSL
    # Builds a single {Node} from step DSL (type, question, options, transitions, visibility).
    # Used by {FlowBuilder#step}; includes {RuleHelpers} for transition/visibility conditions.
    class StepBuilder
      include RuleHelpers

      def initialize
        @type = nil
        @question = nil
        @options = nil
        @fields = nil
        @transitions = []
        @visibility_rule = nil
        @decorations = nil
      end

      # Sets the step/input type (e.g. :multi_select, :number_matrix).
      # @param value [Symbol]
      def type(value)
        @type = value
      end

      # Sets the prompt/label for the step.
      # @param text [String]
      def question(text)
        @question = text
      end

      # Sets the list of options for multi-select or choice steps.
      # @param list [Array]
      def options(list)
        @options = list
      end

      # Sets the list of field names for matrix-style steps (e.g. number_matrix).
      # @param list [Array]
      def fields(list)
        @fields = list
      end

      # Optional UI decorations (opaque to the engine).
      # @param decorations [Object]
      def decorations(decorations)
        @decorations = decorations
      end

      # Adds a conditional transition to another step. First matching transition wins.
      #
      # @param to [Symbol] target step id
      # @param if_rule [Rules::Base, nil] condition (nil = unconditional)
      def transition(to:, if_rule: nil)
        @transitions << Transition.new(target: to, rule: if_rule)
      end

      # Sets the visibility rule for this step (DAG mode: step shown only when rule is true).
      #
      # @param rule [Rules::Base]
      def visible_if(rule)
        @visibility_rule = rule
      end

      # Builds the {Node} for the given step id from accumulated attributes.
      #
      # @param id [Symbol] step id
      # @return [Node]
      def build(id)
        Node.new(
          id: id,
          type: @type,
          question: @question,
          options: @options,
          fields: @fields,
          transitions: @transitions,
          visibility_rule: @visibility_rule,
          decorations: @decorations
        )
      end
    end
  end
end
