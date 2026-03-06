# frozen_string_literal: true

module FlowEngine
  module DSL
    # Builds a {Definition} from the declarative DSL used in {FlowEngine.define}.
    # Provides {#start} and {#step}; each step block is evaluated by {StepBuilder} with {RuleHelpers}.
    class FlowBuilder
      include RuleHelpers

      def initialize
        @start_step_id = nil
        @nodes = {}
      end

      # Sets the entry step id for the flow.
      #
      # @param step_id [Symbol] id of the first step
      def start(step_id)
        @start_step_id = step_id
      end

      # Defines one step by id; the block is evaluated in a {StepBuilder} context.
      #
      # @param id [Symbol] step id
      # @yield block evaluated in {StepBuilder} (type, question, options, transition, etc.)
      def step(id, &)
        builder = StepBuilder.new
        builder.instance_eval(&)
        @nodes[id] = builder.build(id)
      end

      # Produces the frozen {Definition} from the accumulated start and steps.
      #
      # @return [Definition]
      # @raise [DefinitionError] if start was not set or no steps were defined
      def build
        raise DefinitionError, "No start step defined" if @start_step_id.nil?
        raise DefinitionError, "No steps defined" if @nodes.empty?

        Definition.new(start_step_id: @start_step_id, nodes: @nodes)
      end
    end
  end
end
