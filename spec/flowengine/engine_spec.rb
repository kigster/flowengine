# frozen_string_literal: true

RSpec.describe FlowEngine::Engine do
  let(:definition) do
    FlowEngine.define do
      start :step1

      step :step1 do
        type :multi_select
        question "Pick options"
        options %w[A B C]
        transition to: :step2, if_rule: contains(:step1, "B")
        transition to: :step3, if_rule: contains(:step1, "C")
      end

      step :step2 do
        type :text
        question "You picked B"
        transition to: :step3
      end

      step :step3 do
        type :text
        question "Done"
      end
    end
  end

  subject(:engine) { described_class.new(definition) }

  describe "initial state" do
    its(:current_step_id) { is_expected.to eq(:step1) }
    its(:finished?) { is_expected.to be false }
    its(:answers) { is_expected.to eq({}) }
    its(:history) { is_expected.to eq([:step1]) }

    it "returns the start node as current_step" do
      expect(engine.current_step).to be_a(FlowEngine::Node)
      expect(engine.current_step.id).to eq(:step1)
    end
  end

  describe "#answer" do
    it "stores the answer and advances" do
      engine.answer(["B"])
      expect(engine.answers).to eq({ step1: ["B"] })
      expect(engine.current_step_id).to eq(:step2)
    end

    it "tracks history" do
      engine.answer(["B"])
      expect(engine.history).to eq(%i[step1 step2])

      engine.answer("details")
      expect(engine.history).to eq(%i[step1 step2 step3])
    end

    it "takes second transition when first does not match" do
      engine.answer(["C"])
      expect(engine.current_step_id).to eq(:step3)
    end

    it "finishes when no transitions match" do
      engine.answer(["A"])
      expect(engine.finished?).to be true
      expect(engine.current_step_id).to be_nil
      expect(engine.current_step).to be_nil
    end

    it "finishes when last step has no transitions" do
      engine.answer(["B"])
      engine.answer("details")
      engine.answer("final")
      expect(engine.finished?).to be true
    end

    it "raises AlreadyFinishedError when answering after finished" do
      engine.answer(["A"]) # no matching transition -> finished
      expect { engine.answer("more") }.to raise_error(FlowEngine::AlreadyFinishedError)
    end
  end

  describe "multi-step traversal" do
    it "navigates through step1 -> step2 -> step3" do
      engine.answer(["B"])
      expect(engine.current_step_id).to eq(:step2)

      engine.answer("some text")
      expect(engine.current_step_id).to eq(:step3)

      engine.answer("done")
      expect(engine.finished?).to be true

      expect(engine.answers).to eq({
                                     step1: ["B"],
                                     step2: "some text",
                                     step3: "done"
                                   })
    end
  end

  describe "with validator" do
    let(:failing_result) { FlowEngine::Validation::Result.new(valid: false, errors: ["Bad input"]) }
    let(:passing_result) { FlowEngine::Validation::Result.new(valid: true, errors: []) }
    let(:validator) { instance_double(FlowEngine::Validation::Adapter) }

    subject(:engine) { described_class.new(definition, validator: validator) }

    it "raises ValidationError when validation fails" do
      allow(validator).to receive(:validate).and_return(failing_result)
      expect { engine.answer(["B"]) }.to raise_error(FlowEngine::ValidationError, /Bad input/)
    end

    it "does not advance when validation fails" do
      allow(validator).to receive(:validate).and_return(failing_result)
      begin
        engine.answer(["B"])
      rescue FlowEngine::ValidationError
        # expected
      end
      expect(engine.current_step_id).to eq(:step1)
      expect(engine.answers).to eq({})
    end

    it "advances when validation passes" do
      allow(validator).to receive(:validate).and_return(passing_result)
      engine.answer(["B"])
      expect(engine.current_step_id).to eq(:step2)
    end
  end
end
