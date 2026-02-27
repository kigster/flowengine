# frozen_string_literal: true

module FlowEngine
  module Validation
    class NullAdapter < Adapter
      def validate(_node, _input)
        Result.new(valid: true, errors: [])
      end
    end
  end
end
