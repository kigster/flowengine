# frozen_string_literal: true

module FlowEngine
  module LLM
    # Builds the system prompt for the LLM from the static template
    # and dynamic step metadata from the flow Definition.
    class SystemPromptBuilder
      TEMPLATE_PATH = File.expand_path("../../../resources/prompts/generic-dsl-intake.j2", __dir__)

      # @param definition [Definition] flow definition to describe
      # @param template_path [String] path to the static prompt template
      def initialize(definition, template_path: TEMPLATE_PATH)
        @definition = definition
        @template_path = template_path
      end

      # @return [String] complete system prompt (static template + step descriptions + response format)
      def build
        [static_prompt, steps_description, response_format].join("\n\n")
      end

      private

      def static_prompt
        File.read(@template_path)
      end

      def steps_description
        lines = ["## Flow Steps\n"]
        @definition.steps.each_value { |node| append_step_description(lines, node) }
        lines.join("\n")
      end

      def append_step_description(lines, node)
        lines << "### Step: `#{node.id}`"
        lines << "- **Type**: #{node.type}"
        lines << "- **Question**: #{node.question}"
        append_options(lines, node) if node.options&.any?
        lines << "- **Fields**: #{node.fields.join(", ")}" if node.fields&.any?
        lines << ""
      end

      def append_options(lines, node)
        if node.option_labels
          formatted = node.option_labels.map { |key, label| "#{key} (#{label})" }.join(", ")
          lines << "- **Options**: #{formatted}"
          lines << "- **Use the option keys in your response, not the labels**"
        else
          lines << "- **Options**: #{node.options.join(", ")}"
        end
      end

      def response_format
        <<~PROMPT
          ## Response Format

          Respond with ONLY a valid JSON object mapping step IDs (as strings) to extracted values.
          Only include steps where you can confidently extract an answer from the user's text.
          Do not guess or fabricate answers. If unsure, omit that step.

          Value types by step type:
          - `single_select`: one of the listed option strings
          - `multi_select`: an array of matching option strings
          - `number`: an integer
          - `text`: extracted text string
          - `number_matrix`: a hash mapping field names to integers (e.g. {"RealEstate": 2, "LLC": 1})

          Example: {"filing_status": "single", "dependents": 2, "income_types": ["W2", "Business"]}
        PROMPT
      end
    end
  end
end
