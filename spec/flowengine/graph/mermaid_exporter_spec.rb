# frozen_string_literal: true

RSpec.describe FlowEngine::Graph::MermaidExporter do
  describe "#export" do
    it "generates Mermaid flowchart syntax" do
      definition = FlowEngine.define do
        start :step1

        step :step1 do
          type :multi_select
          question "Pick options"
          transition to: :step2, if_rule: contains(:step1, "A")
          transition to: :step3
        end

        step :step2 do
          type :text
          question "Step 2"
          transition to: :step3
        end

        step :step3 do
          type :text
          question "Done"
        end
      end

      exporter = described_class.new(definition)
      output = exporter.export

      expect(output).to include("flowchart TD")
      expect(output).to include('step1["Pick options"]')
      expect(output).to include('step2["Step 2"]')
      expect(output).to include('step3["Done"]')
      expect(output).to include('step1 -->|"A in step1"| step2')
      expect(output).to include("step1 --> step3")
      expect(output).to include("step2 --> step3")
    end

    it "truncates long question text" do
      definition = FlowEngine.define do
        start :step1

        step :step1 do
          type :text
          question "This is a very long question that exceeds the maximum label length for Mermaid nodes"
        end
      end

      exporter = described_class.new(definition)
      output = exporter.export

      expect(output).to include('step1["This is a very long question that exceeds the maxi..."]')
    end

    it "handles nodes with no transitions" do
      definition = FlowEngine.define do
        start :only

        step :only do
          type :text
          question "Only step"
        end
      end

      exporter = described_class.new(definition)
      output = exporter.export

      expect(output).to include('only["Only step"]')
      # No transition lines
      lines = output.split("\n")
      expect(lines.count { |l| l.include?("-->") }).to eq(0)
    end
  end
end
