# frozen_string_literal: true

module FlowEngine
  # Runtime session that drives flow navigation: holds definition, answers, and current step.
  # Validates each answer via an optional {Validation::Adapter}, then advances using node transitions.
  #
  # @attr_reader definition [Definition] immutable flow definition
  # @attr_reader answers [Hash] step_id => value (mutable as user answers)
  # @attr_reader history [Array<Symbol>] ordered list of step ids visited (including current)
  # @attr_reader current_step_id [Symbol, nil] current step id, or nil when flow is finished
  class Engine
    attr_reader :definition, :answers, :history, :current_step_id

    # @param definition [Definition] the flow to run
    # @param validator [Validation::Adapter] validator for step answers (default: {Validation::NullAdapter})
    def initialize(definition, validator: Validation::NullAdapter.new)
      @definition = definition
      @answers = {}
      @history = []
      @current_step_id = definition.start_step_id
      @validator = validator
      @history << @current_step_id
    end

    # @return [Node, nil] current step node, or nil if flow is finished
    def current_step
      return nil if finished?

      definition.step(@current_step_id)
    end

    # @return [Boolean] true when there is no current step (flow ended)
    def finished?
      @current_step_id.nil?
    end

    # Submits an answer for the current step, validates it, stores it, and advances to the next step.
    #
    # @param value [Object] user's answer for the current step
    # @raise [AlreadyFinishedError] if the flow has already finished
    # @raise [ValidationError] if the validator rejects the value
    def answer(value)
      raise AlreadyFinishedError, "Flow is already finished" if finished?

      result = @validator.validate(current_step, value)
      raise ValidationError, "Validation failed: #{result.errors.join(", ")}" unless result.valid?

      answers[@current_step_id] = value
      advance_step
    end

    # Serializable state for persistence or resumption.
    #
    # @return [Hash] current_step_id, answers, and history (string/symbol keys as stored)
    def to_state
      {
        current_step_id: @current_step_id,
        answers: @answers,
        history: @history
      }
    end

    # Rebuilds an engine from a previously saved state (e.g. from DB or session).
    #
    # @param definition [Definition] same definition used when state was captured
    # @param state_hash [Hash] hash with :current_step_id, :answers, :history (keys may be strings)
    # @param validator [Validation::Adapter] validator to use (default: NullAdapter)
    # @return [Engine] restored engine instance
    def self.from_state(definition, state_hash, validator: Validation::NullAdapter.new)
      state = symbolize_state(state_hash)
      engine = allocate
      engine.send(:restore_state, definition, state, validator)
      engine
    end

    # Normalizes a state hash so step ids and history entries are symbols; answers keys are symbols.
    #
    # @param hash [Hash] raw state (e.g. from JSON)
    # @return [Hash] symbolized state
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

    # @param answers [Hash] answers map (keys may be strings)
    # @return [Hash] same map with symbol keys
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
