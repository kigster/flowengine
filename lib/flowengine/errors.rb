# frozen_string_literal: true

module FlowEngine
  module Errors
    # Base exception for all flowengine errors.
    class Error < StandardError; end

    # Raised when configuration is invalid (e.g. missing models.yml).
    class ConfigurationError < Error; end

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

    # Raised when introduction text contains sensitive data (SSN, ITIN, EIN, etc.).
    class SensitiveDataError < EngineError; end

    # Base exception for LLM-related errors (missing API key, response parsing, etc.).
    class LLMError < Error; end

    # Raised when no API key is found for any provider.
    class NoAPIKeyFoundError < LLMError; end

    # Raised when a requested provider does not exist.
    class NoSuchProviderExists < LLMError; end

    # Raised when a provider is missing its API key.
    class ProviderMissingApiKey < LLMError; end

    # Raised when a requested model is not available.
    class ModelNotAvailable < LLMError; end

    # Raised when the LLM provider rejects the request due to rate limits or budget.
    class OutOfBudgetError < LLMError; end

    # Raised when the LLM provider rejects authentication credentials.
    class AuthorizationError < LLMError; end
  end
end
