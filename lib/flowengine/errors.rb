# frozen_string_literal: true

module FlowEngine
  class Error < StandardError; end
  class DefinitionError < Error; end
  class UnknownStepError < Error; end
  class EngineError < Error; end
  class AlreadyFinishedError < EngineError; end
  class ValidationError < EngineError; end
end
