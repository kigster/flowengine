# frozen_string_literal: true

module FlowEngine
  # Immutable result from an AI intake or clarification round.
  #
  # @attr_reader answered [Hash<Symbol, Object>] step_id => value pairs filled this round
  # @attr_reader pending_steps [Array<Symbol>] step ids still unanswered after this round
  # @attr_reader follow_up [String, nil] clarifying question from the LLM, or nil if done
  # @attr_reader round [Integer] current clarification round (1-based)
  ClarificationResult = Data.define(:answered, :pending_steps, :follow_up, :round) do
    def initialize(answered: {}, pending_steps: [], follow_up: nil, round: 1)
      super
      freeze
    end

    # @return [Boolean] true when the LLM has no more questions or max rounds reached
    def done?
      follow_up.nil?
    end
  end
end
