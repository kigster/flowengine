# frozen_string_literal: true

module FlowEngine
  module LLM
    # Builds system prompts for AI intake steps. Unlike SystemPromptBuilder (used for
    # the definition-level introduction), this builder is aware of already-answered steps,
    # conversation history, and instructs the LLM to optionally ask follow-up questions.
    class IntakePromptBuilder
      # @param definition [Definition] flow definition
      # @param answered [Hash<Symbol, Object>] already-answered step_id => value pairs
      # @param conversation_history [Array<Hash>] prior rounds: [{role:, text:}, ...]
      def initialize(definition, answered: {}, conversation_history: [])
        @definition = definition
        @answered = answered
        @conversation_history = conversation_history
      end

      # @return [String] system prompt for the LLM
      def build
        sections = [
          context_section,
          unanswered_steps_section,
          answered_steps_section,
          conversation_history_section,
          response_format_section
        ].compact

        sections.join("\n\n")
      end

      private

      def context_section
        <<~PROMPT
          ## Context

          You are an intake assistant. The user is providing free-form text to answer
          questions in a structured intake form. Your job is to:

          1. Extract as many answers as you can from the user's text
          2. If critical information is still missing, ask ONE concise follow-up question
          3. If you have enough information or cannot reasonably ask more, return no follow-up

          NEVER ask for sensitive information (SSN, ITIN, EIN, bank account numbers, date of birth).
          Do not fabricate answers. Only extract what the user clearly stated.
        PROMPT
      end

      def unanswered_steps_section
        unanswered = @definition.steps.reject { |id, node| @answered.key?(id) || node.ai_intake? }
        return nil if unanswered.empty?

        lines = ["## Unanswered Steps (fill these from the user's text)\n"]
        unanswered.each_value { |node| append_step_description(lines, node) }
        lines.join("\n")
      end

      def answered_steps_section
        return nil if @answered.empty?

        lines = ["## Already Answered Steps (do not re-ask these)\n"]
        @answered.each do |step_id, value|
          next unless @definition.steps.key?(step_id)

          node = @definition.step(step_id)
          lines << "- **#{step_id}** (#{node.question}): `#{value.inspect}`"
        end
        lines << ""
        lines.join("\n")
      end

      def conversation_history_section
        return nil if @conversation_history.empty?

        lines = ["## Conversation History\n"]
        @conversation_history.each do |entry|
          role = entry[:role] == :user ? "User" : "Assistant"
          lines << "**#{role}**: #{entry[:text]}"
          lines << ""
        end
        lines.join("\n")
      end

      def response_format_section
        <<~PROMPT
          ## Response Format

          Respond with ONLY a valid JSON object with two keys:

          1. `"answers"` — a JSON object mapping step IDs to extracted values. Only include
             steps where you can confidently extract an answer. Value types:
             - `single_select`: one of the listed option strings
             - `multi_select`: an array of matching option strings
             - `number`: an integer
             - `text`: extracted text string
             - `number_matrix`: a hash mapping field names to integers

          2. `"follow_up"` — either a string with ONE concise clarifying question, or `null`
             if you have no more questions. Focus on the most important unanswered step.

          Example:
          ```json
          {
            "answers": {"filing_status": "married_joint", "dependents": 2},
            "follow_up": "What types of income do you have — W2, 1099, business, or investment?"
          }
          ```
        PROMPT
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
    end
  end
end
