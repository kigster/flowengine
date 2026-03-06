# frozen_string_literal: true

require_relative "dsl/rule_helpers"
require_relative "dsl/step_builder"
require_relative "dsl/flow_builder"

module FlowEngine
  # Namespace for the declarative flow DSL: {FlowBuilder} builds a {Definition} from blocks,
  # {StepBuilder} builds individual {Node}s, and {RuleHelpers} provide rule factory methods.
  module DSL
  end
end
