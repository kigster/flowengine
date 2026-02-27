# frozen_string_literal: true

module FlowEngine
  module DSL
    class FlowBuilder
      include RuleHelpers

      def initialize
        @start_step_id = nil
        @nodes = {}
      end

      def start(step_id)
        @start_step_id = step_id
      end

      def step(id, &)
        builder = StepBuilder.new
        builder.instance_eval(&)
        @nodes[id] = builder.build(id)
      end

      def build
        raise DefinitionError, "No start step defined" if @start_step_id.nil?
        raise DefinitionError, "No steps defined" if @nodes.empty?

        Definition.new(start_step_id: @start_step_id, nodes: @nodes)
      end
    end
  end
end
