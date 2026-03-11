# frozen_string_literal: true

require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.inflector.inflect(
  "flowengine" => "FlowEngine",
  "llm" => "LLM",
  "dsl" => "DSL"
)
loader.setup

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
  # Root directory of the flowengine gem
  ROOT = File.expand_path("..", __dir__)

  # Builds an immutable {Definition} from the declarative DSL block.
  #
  # @yield context of {DSL::FlowBuilder} (start, step, and rule helpers)
  # @return [Definition] frozen flow definition with start step and nodes
  # @raise [Errors::DefinitionError] if no start step or no steps are defined
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
  # @raise [Errors::DefinitionError] on syntax or evaluation errors
  def self.load_dsl(text)
    # rubocop:disable Security/Eval
    eval(text, TOPLEVEL_BINDING.dup, "(dsl)", 1)
    # rubocop:enable Security/Eval
  rescue SyntaxError => e
    raise Errors::DefinitionError, "DSL syntax error: #{e.message}"
  rescue StandardError => e
    raise Errors::DefinitionError, "DSL evaluation error: #{e.message}"
  end

  # Resolves a fully-qualified constant name string to the actual constant.
  #
  # @param name [String] e.g. "FlowEngine::LLM::Adapters::AnthropicAdapter"
  # @return [Class, Module]
  def self.constantize(name)
    name.split("::").inject(Object) { |mod, const| mod.const_get(const) }
  end
end
