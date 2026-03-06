# frozen_string_literal: true

module FlowEngine
  module Validation
    # No-op validator: always accepts any input. Used by default when no validation adapter is given.
    class NullAdapter < Adapter
      # @param _node [Node] ignored
      # @param _input [Object] ignored
      # @return [Result] always valid with no errors
      def validate(_node, _input)
        Result.new(valid: true, errors: [])
      end
    end
  end
end
