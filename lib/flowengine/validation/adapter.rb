# frozen_string_literal: true

module FlowEngine
  module Validation
    # Result of validating a step answer: either valid or a list of error messages.
    #
    # @attr_reader errors [Array<String>] validation error messages (empty when valid)
    class Result
      attr_reader :errors

      # @param valid [Boolean] whether the input passed validation
      # @param errors [Array<String>] error messages (default: [])
      def initialize(valid:, errors: [])
        @valid = valid
        @errors = errors.freeze
        freeze
      end

      # @return [Boolean] true if validation passed
      def valid?
        @valid
      end
    end

    # Abstract adapter for step-level validation. Implement {#validate} to plug in
    # dry-validation, JSON Schema, or other validators; the engine does not depend on a specific one.
    class Adapter
      # Validates the user's input for the given step.
      #
      # @param _node [Node] the current step (for schema/constraints)
      # @param _input [Object] the value submitted by the user
      # @return [Result] valid: true/false and optional errors list
      def validate(_node, _input)
        raise NotImplementedError, "#{self.class}#validate must be implemented"
      end
    end
  end
end
