# frozen_string_literal: true

module FlowEngine
  # Runtime session that drives flow navigation: holds definition, answers, and current step.
  # Validates each answer via an optional {Validation::Adapter}, then advances using node transitions.
  class Engine # rubocop:disable Metrics/ClassLength
    attr_reader :definition, :answers, :history, :current_step_id, :introduction_text,
                :clarification_round, :conversation_history

    # @param definition [Definition] the flow to run
    # @param validator [Validation::Adapter] validator for step answers (default: {Validation::NullAdapter})
    def initialize(definition, validator: Validation::NullAdapter.new)
      @definition = definition
      @answers = {}
      @history = []
      @current_step_id = definition.start_step_id
      @validator = validator
      @introduction_text = nil
      @clarification_round = 0
      @conversation_history = []
      @active_intake_step_id = nil
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
      raise Errors::AlreadyFinishedError, "Flow is already finished" if finished?

      result = @validator.validate(current_step, value)
      raise Errors::ValidationError, "Validation failed: #{result.errors.join(", ")}" unless result.valid?

      answers[@current_step_id] = value
      advance_step
    end

    # Submits free-form introduction text, filters sensitive data, calls the LLM
    # to extract answers, and auto-advances through pre-filled steps.
    #
    # @param text [String] user's free-form introduction
    # @param llm_client [LLM::Client] configured LLM client for parsing
    def submit_introduction(text, llm_client:)
      validate_introduction_length!(text)
      LLM::SensitiveDataFilter.check!(text)
      @introduction_text = text
      extracted = llm_client.parse_introduction(definition: @definition, introduction_text: text)
      @answers.merge!(extracted)
      auto_advance_prefilled
    end

    # Submits free-form text for the current AI intake step. Returns a ClarificationResult.
    #
    # @param text [String] user's free-form text
    # @param llm_client [LLM::Client] configured LLM client
    # @return [ClarificationResult]
    def submit_ai_intake(text, llm_client:)
      node = current_step
      raise Errors::EngineError, "Current step is not an AI intake step" unless node&.ai_intake?

      LLM::SensitiveDataFilter.check!(text)

      @active_intake_step_id = @current_step_id
      @clarification_round = 1
      @conversation_history = [{ role: :user, text: text }]

      perform_intake_round(text, llm_client, node)
    end

    # Submits a clarification response for an ongoing AI intake conversation.
    #
    # @param text [String] user's response to the follow-up question
    # @param llm_client [LLM::Client] configured LLM client
    # @return [ClarificationResult]
    def submit_clarification(text, llm_client:)
      raise Errors::EngineError, "No active AI intake conversation to clarify" unless @active_intake_step_id

      LLM::SensitiveDataFilter.check!(text)

      node = @definition.step(@active_intake_step_id)
      @clarification_round += 1
      @conversation_history << { role: :user, text: text }

      perform_intake_round(text, llm_client, node)
    end

    # Serializable state for persistence or resumption.
    def to_state
      {
        current_step_id: @current_step_id,
        answers: @answers,
        history: @history,
        introduction_text: @introduction_text,
        clarification_round: @clarification_round,
        conversation_history: @conversation_history,
        active_intake_step_id: @active_intake_step_id
      }
    end

    # Rebuilds an engine from a previously saved state.
    #
    # @param definition [Definition] same definition used when state was captured
    # @param state_hash [Hash] hash with state keys (may be strings from JSON)
    # @param validator [Validation::Adapter] validator to use (default: NullAdapter)
    # @return [Engine] restored engine instance
    def self.from_state(definition, state_hash, validator: Validation::NullAdapter.new)
      state = StateSerializer.symbolize_state(state_hash)
      engine = allocate
      engine.send(:restore_state, definition, state, validator)
      engine
    end

    private

    def restore_state(definition, state, validator)
      @definition = definition
      @validator = validator
      @current_step_id = state[:current_step_id]
      @answers = state[:answers] || {}
      @history = state[:history] || []
      @introduction_text = state[:introduction_text]
      @clarification_round = state[:clarification_round] || 0
      @conversation_history = state[:conversation_history] || []
      @active_intake_step_id = state[:active_intake_step_id]
    end

    def advance_step
      node = definition.step(@current_step_id)
      next_id = node.next_step_id(answers)
      @current_step_id = next_id
      @history << next_id if next_id
    end

    def validate_introduction_length!(text)
      maxlength = @definition.introduction&.maxlength
      return unless maxlength
      return if text.length <= maxlength

      raise Errors::ValidationError, "Introduction text exceeds maxlength (#{text.length}/#{maxlength})"
    end

    def auto_advance_prefilled
      advance_step while @current_step_id && @answers.key?(@current_step_id)
    end

    def perform_intake_round(user_text, llm_client, node)
      result = llm_client.parse_ai_intake(
        definition: @definition, user_text: user_text,
        answered: @answers, conversation_history: @conversation_history
      )
      @answers.merge!(result[:answers])
      follow_up = resolve_follow_up(result[:follow_up], node)

      build_clarification_result(result[:answers], follow_up)
    end

    def resolve_follow_up(follow_up, node)
      if follow_up && @clarification_round <= node.max_clarifications
        @conversation_history << { role: :assistant, text: follow_up }
        follow_up
      else
        finalize_intake
        nil
      end
    end

    def build_clarification_result(round_answers, follow_up)
      ClarificationResult.new(
        answered: round_answers,
        pending_steps: pending_non_intake_steps,
        follow_up: follow_up,
        round: @clarification_round
      )
    end

    def finalize_intake
      @answers[@active_intake_step_id] = conversation_summary
      @active_intake_step_id = nil
      advance_step
      auto_advance_prefilled
    end

    def conversation_summary
      @conversation_history.map { |e| "#{e[:role]}: #{e[:text]}" }.join("\n")
    end

    def pending_non_intake_steps
      @definition.steps.each_with_object([]) do |(id, node), pending|
        pending << id unless node.ai_intake? || @answers.key?(id)
      end
    end
  end
end
