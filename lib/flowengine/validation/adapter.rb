# frozen_string_literal: true

module FlowEngine
  module Validation
    class Result
      attr_reader :errors

      def initialize(valid:, errors: [])
        @valid = valid
        @errors = errors.freeze
        freeze
      end

      def valid?
        @valid
      end
    end

    class Adapter
      def validate(_node, _input)
        raise NotImplementedError, "#{self.class}#validate must be implemented"
      end
    end
  end
end
