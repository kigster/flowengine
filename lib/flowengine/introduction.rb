# frozen_string_literal: true

module FlowEngine
  # Immutable introduction configuration for a flow. When present in a Definition,
  # indicates the UI should collect free-form text before the first step.
  # The label is shown above the input field; the placeholder appears inside it.
  # maxlength limits the character count of the free-form text (nil = unlimited).
  Introduction = Data.define(:label, :placeholder, :maxlength) do
    def initialize(label:, placeholder: "", maxlength: nil)
      super
      freeze
    end
  end
end
