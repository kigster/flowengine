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
        @introduction = nil
      end

      # Sets the entry step id for the flow.
      #
      # @param step_id [Symbol] id of the first step
      def start(step_id)
        @start_step_id = step_id
      end

      # Configures an introduction step that collects free-form text before the flow begins.
      # The LLM parses this text to pre-fill answers for subsequent steps.
      #
      # @param label [String] text shown above the input field
      # @param placeholder [String] text shown inside the empty text area
      # @param maxlength [Integer, nil] maximum character count for the text (nil = unlimited)
      def introduction(label:, placeholder: "", maxlength: nil)
        @introduction = Introduction.new(label: label, placeholder: placeholder, maxlength: maxlength)
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
        raise ::FlowEngine::Errors::DefinitionError, "No start step defined" if @start_step_id.nil?
        raise ::FlowEngine::Errors::DefinitionError, "No steps defined" if @nodes.empty?

        Definition.new(start_step_id: @start_step_id, nodes: @nodes, introduction: @introduction)
      end
    end
  end
end
