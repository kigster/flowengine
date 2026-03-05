# frozen_string_literal: true

module FlowEngine
  module DSL
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

      def type(value)
        @type = value
      end

      def question(text)
        @question = text
      end

      def options(list)
        @options = list
      end

      def fields(list)
        @fields = list
      end

      def decorations(decorations)
        @decorations = decorations
      end

      def transition(to:, if_rule: nil)
        @transitions << Transition.new(target: to, rule: if_rule)
      end

      def visible_if(rule)
        @visibility_rule = rule
      end

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
