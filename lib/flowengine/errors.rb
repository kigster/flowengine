# frozen_string_literal: true

module FlowEngine
  # Base exception for all flowengine errors.
  class Error < StandardError; end

  # Raised when a flow definition is invalid (e.g. missing start step, unknown step reference).
  class DefinitionError < Error; end

  # Raised when navigating to or requesting a step id that does not exist in the definition.
  class UnknownStepError < Error; end

  # Base exception for runtime engine errors (e.g. validation, already finished).
  class EngineError < Error; end

  # Raised when {Engine#answer} is called after the flow has already finished.
  class AlreadyFinishedError < EngineError; end

  # Raised when the validator rejects the user's answer for the current step.
  class ValidationError < EngineError; end

  # Raised for LLM-related errors (missing API key, response parsing, etc.).
  class LLMError < Error; end

  # Raised when introduction text contains sensitive data (SSN, ITIN, EIN, etc.).
  class SensitiveDataError < EngineError; end
end
