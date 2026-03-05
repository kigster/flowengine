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

    def to_state
      {
        current_step_id: @current_step_id,
        answers: @answers,
        history: @history
      }
    end

    def self.from_state(definition, state_hash, validator: Validation::NullAdapter.new)
      state = symbolize_state(state_hash)
      engine = allocate
      engine.send(:restore_state, definition, state, validator)
      engine
    end

    def self.symbolize_state(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(key, value), result|
        sym_key = key.to_sym
        result[sym_key] = case sym_key
                          when :current_step_id
                            value&.to_sym
                          when :history
                            Array(value).map { |v| v&.to_sym }
                          when :answers
                            symbolize_answers(value)
                          else
                            value
                          end
      end
    end

    def self.symbolize_answers(answers)
      return {} unless answers.is_a?(Hash)

      answers.each_with_object({}) do |(key, value), result|
        result[key.to_sym] = value
      end
    end

    private_class_method :symbolize_state, :symbolize_answers

    private

    def restore_state(definition, state, validator)
      @definition = definition
      @validator = validator
      @current_step_id = state[:current_step_id]
      @answers = state[:answers] || {}
      @history = state[:history] || []
    end

    def advance_step
      node = definition.step(@current_step_id)
      next_id = node.next_step_id(answers)

      @current_step_id = next_id
      @history << next_id if next_id
    end
  end
end
