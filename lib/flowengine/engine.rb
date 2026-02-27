# frozen_string_literal: true

module FlowEngine
  class Engine
    attr_reader :definition, :answers, :history, :current_step_id

    def initialize(definition, validator: Validation::NullAdapter.new)
      @definition = definition
      @answers = {}
      @history = []
      @current_step_id = definition.start_step_id
      @validator = validator
      @history << @current_step_id
    end

    def current_step
      return nil if finished?

      definition.step(@current_step_id)
    end

    def finished?
      @current_step_id.nil?
    end

    def answer(value)
      raise AlreadyFinishedError, "Flow is already finished" if finished?

      result = @validator.validate(current_step, value)
      raise ValidationError, "Validation failed: #{result.errors.join(", ")}" unless result.valid?

      answers[@current_step_id] = value
      advance_step
    end

    private

    def advance_step
      node = definition.step(@current_step_id)
      next_id = node.next_step_id(answers)

      @current_step_id = next_id
      @history << next_id if next_id
    end
  end
end
