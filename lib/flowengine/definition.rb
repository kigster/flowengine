# frozen_string_literal: true

module FlowEngine
  class Definition
    attr_reader :start_step_id, :steps

    def initialize(start_step_id:, nodes:)
      @start_step_id = start_step_id
      @steps = nodes.freeze
      validate!
      freeze
    end

    def start_step
      step(start_step_id)
    end

    def step(id)
      steps.fetch(id) { raise UnknownStepError, "Unknown step: #{id.inspect}" }
    end

    def step_ids
      steps.keys
    end

    private

    def validate!
      raise DefinitionError, "Start step #{start_step_id.inspect} not found in nodes" unless steps.key?(start_step_id)
    end
  end
end
