# frozen_string_literal: true

require_relative "flowengine/version"
require_relative "flowengine/errors"
require_relative "flowengine/rules/base"
require_relative "flowengine/rules/contains"
require_relative "flowengine/rules/equals"
require_relative "flowengine/rules/greater_than"
require_relative "flowengine/rules/less_than"
require_relative "flowengine/rules/not_empty"
require_relative "flowengine/rules/all"
require_relative "flowengine/rules/any"
require_relative "flowengine/evaluator"
require_relative "flowengine/transition"
require_relative "flowengine/node"
require_relative "flowengine/introduction"
require_relative "flowengine/definition"
require_relative "flowengine/validation/adapter"
require_relative "flowengine/validation/null_adapter"
require_relative "flowengine/engine"
require_relative "flowengine/dsl"
require_relative "flowengine/graph/mermaid_exporter"
require_relative "flowengine/llm"

# Declarative flow definition and execution engine for wizards, intake forms, and
# multi-step decision graphs. Separates flow logic, data schema, and UI rendering.
#
# @example Define and run a flow
#   definition = FlowEngine.define do
#     start :earnings
#     step :earnings do
#       type :multi_select
#       question "What are your main earnings?"
#       options %w[W2 1099 BusinessOwnership]
#       transition to: :business_details, if: contains(:earnings, "BusinessOwnership")
#     end
#     step :business_details do
#       type :number_matrix
#       question "How many business types?"
#       fields %w[RealEstate SCorp CCorp]
#     end
#   end
#   engine = FlowEngine::Engine.new(definition)
#   engine.answer(["W2", "BusinessOwnership"])
#   engine.current_step_id # => :business_details
#
module FlowEngine
  # Builds an immutable {Definition} from the declarative DSL block.
  #
  # @yield context of {DSL::FlowBuilder} (start, step, and rule helpers)
  # @return [Definition] frozen flow definition with start step and nodes
  # @raise [DefinitionError] if no start step or no steps are defined
  def self.define(&)
    builder = DSL::FlowBuilder.new
    builder.instance_eval(&)
    builder.build
  end

  # Evaluates a string of DSL code and returns the resulting definition.
  # Intended for loading flow definitions from files or stored text.
  #
  # @param text [String] Ruby source containing FlowEngine.define { ... }
  # @return [Definition] the definition produced by evaluating the DSL
  # @raise [DefinitionError] on syntax or evaluation errors
  def self.load_dsl(text)
    # rubocop:disable Security/Eval
    eval(text, TOPLEVEL_BINDING.dup, "(dsl)", 1)
    # rubocop:enable Security/Eval
  rescue SyntaxError => e
    raise DefinitionError, "DSL syntax error: #{e.message}"
  rescue StandardError => e
    raise DefinitionError, "DSL evaluation error: #{e.message}"
  end
end
