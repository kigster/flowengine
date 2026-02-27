# frozen_string_literal: true

RSpec.describe FlowEngine::Definition do
  let(:node1) { FlowEngine::Node.new(id: :step1, type: :text, question: "Q1") }
  let(:node2) { FlowEngine::Node.new(id: :step2, type: :text, question: "Q2") }

  subject(:definition) do
    described_class.new(start_step_id: :step1, nodes: { step1: node1, step2: node2 })
  end

  its(:start_step_id) { is_expected.to eq(:step1) }

  it "is frozen" do
    expect(definition).to be_frozen
  end

  it "has frozen steps" do
    expect(definition.steps).to be_frozen
  end

  describe "#start_step" do
    it "returns the start node" do
      expect(definition.start_step).to eq(node1)
    end
  end

  describe "#step" do
    it "returns a node by id" do
      expect(definition.step(:step1)).to eq(node1)
      expect(definition.step(:step2)).to eq(node2)
    end

    it "raises UnknownStepError for missing step" do
      expect { definition.step(:nonexistent) }.to raise_error(FlowEngine::UnknownStepError, /nonexistent/)
    end
  end

  describe "#step_ids" do
    it "returns all step ids" do
      expect(definition.step_ids).to contain_exactly(:step1, :step2)
    end
  end

  describe "validation" do
    it "raises DefinitionError when start step is not in nodes" do
      expect do
        described_class.new(start_step_id: :missing, nodes: { step1: node1 })
      end.to raise_error(FlowEngine::DefinitionError, /Start step :missing not found/)
    end
  end
end
