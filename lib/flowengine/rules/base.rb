# frozen_string_literal: true

module FlowEngine
  module Rules
    class Base
      def evaluate(_answers)
        raise NotImplementedError, "#{self.class}#evaluate must be implemented"
      end

      def to_s
        raise NotImplementedError, "#{self.class}#to_s must be implemented"
      end
    end
  end
end
