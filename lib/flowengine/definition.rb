# frozen_string_literal: true

module FlowEngine
  # Immutable, versionable flow graph: maps step ids to {Node} objects and defines the entry point.
  # Built by {DSL::FlowBuilder}; consumed by {Engine} for navigation.
  #
  # @attr_reader start_step_id [Symbol] id of the first step in the flow
  # @attr_reader steps [Hash<Symbol, Node>] frozen map of step id => node (read-only)
  class Definition
    attr_reader :start_step_id, :steps, :introduction

    # @param start_step_id [Symbol] id of the initial step
    # @param nodes [Hash<Symbol, Node>] all steps keyed by id
    # @param introduction [Introduction, nil] optional introduction config (label + placeholder)
    # @raise [DefinitionError] if start_step_id is not present in nodes
    def initialize(start_step_id:, nodes:, introduction: nil)
      @start_step_id = start_step_id
      @steps = nodes.freeze
      @introduction = introduction
      validate!
      freeze
    end

    # @return [Node] the node for the start step
    def start_step
      step(start_step_id)
    end

    # @param id [Symbol] step id
    # @return [Node] the node for that step
    # @raise [UnknownStepError] if id is not in steps
    def step(id)
      steps.fetch(id) { raise UnknownStepError, "Unknown step: #{id.inspect}" }
    end

    # @return [Array<Symbol>] all step ids in the definition
    def step_ids
      steps.keys
    end

    private

    def validate!
      raise DefinitionError, "Start step #{start_step_id.inspect} not found in nodes" unless steps.key?(start_step_id)
    end
  end
end
