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
require_relative "flowengine/definition"
require_relative "flowengine/validation/adapter"
require_relative "flowengine/validation/null_adapter"
require_relative "flowengine/engine"
require_relative "flowengine/dsl"
require_relative "flowengine/graph/mermaid_exporter"

module FlowEngine
  def self.define(&)
    builder = DSL::FlowBuilder.new
    builder.instance_eval(&)
    builder.build
  end

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
