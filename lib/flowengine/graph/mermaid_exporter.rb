# frozen_string_literal: true

module FlowEngine
  module Graph
    # Exports a flow {Definition} to Mermaid flowchart syntax for visualization.
    # Nodes are labeled with truncated question text; edges show condition labels when present.
    class MermaidExporter
      # Maximum characters for node labels in the diagram (longer text is truncated with "...").
      MAX_LABEL_LENGTH = 50

      attr_reader :definition

      # @param definition [Definition] flow to export
      def initialize(definition)
        @definition = definition
      end

      # Generates Mermaid flowchart TD (top-down) source.
      #
      # @return [String] Mermaid diagram source (e.g. for Mermaid.js or docs)
      def export
        lines = ["flowchart TD"]

        definition.steps.each_value do |node|
          lines << "  #{node.id}[\"#{truncate(node.question)}\"]"

          node.transitions.each do |transition|
            label = transition.condition_label
            lines << if label == "always"
                       "  #{node.id} --> #{transition.target}"
                     else
                       "  #{node.id} -->|\"#{label}\"| #{transition.target}"
                     end
          end
        end

        lines.join("\n")
      end

      private

      def truncate(text)
        return "" if text.nil?
        return text if text.length <= MAX_LABEL_LENGTH

        "#{text[0, MAX_LABEL_LENGTH]}..."
      end
    end
  end
end
