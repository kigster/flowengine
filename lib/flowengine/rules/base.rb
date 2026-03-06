# frozen_string_literal: true

module FlowEngine
  module Rules
    # Abstract base for rule AST nodes. Subclasses implement {#evaluate} and {#to_s}
    # for use in transitions and visibility conditions.
    class Base
      # Evaluates the rule against the current answer context.
      #
      # @param _answers [Hash] step_id => value
      # @return [Boolean]
      def evaluate(_answers)
        raise NotImplementedError, "#{self.class}#evaluate must be implemented"
      end

      # Human-readable representation (e.g. for graph labels).
      #
      # @return [String]
      def to_s
        raise NotImplementedError, "#{self.class}#to_s must be implemented"
      end
    end
  end
end
