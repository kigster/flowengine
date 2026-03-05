# frozen_string_literal: true

RSpec.describe "Engine state persistence" do
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

  describe "Engine#to_state" do
    it "returns initial state" do
      engine = FlowEngine::Engine.new(definition)
      state = engine.to_state

      expect(state[:current_step_id]).to eq(:step1)
      expect(state[:answers]).to eq({})
      expect(state[:history]).to eq([:step1])
    end

    it "returns state after answering" do
      engine = FlowEngine::Engine.new(definition)
      engine.answer(["B"])

      state = engine.to_state
      expect(state[:current_step_id]).to eq(:step2)
      expect(state[:answers]).to eq({ step1: ["B"] })
      expect(state[:history]).to eq(%i[step1 step2])
    end

    it "returns state when finished" do
      engine = FlowEngine::Engine.new(definition)
      engine.answer(["A"]) # no matching transition -> finished

      state = engine.to_state
      expect(state[:current_step_id]).to be_nil
      expect(state[:answers]).to eq({ step1: ["A"] })
    end
  end

  describe "Engine.from_state" do
    it "restores engine from initial state" do
      original = FlowEngine::Engine.new(definition)
      state = original.to_state

      restored = FlowEngine::Engine.from_state(definition, state)
      expect(restored.current_step_id).to eq(:step1)
      expect(restored.answers).to eq({})
      expect(restored.history).to eq([:step1])
      expect(restored.finished?).to be false
    end

    it "restores engine mid-flow" do
      original = FlowEngine::Engine.new(definition)
      original.answer(["B"])
      state = original.to_state

      restored = FlowEngine::Engine.from_state(definition, state)
      expect(restored.current_step_id).to eq(:step2)
      expect(restored.answers).to eq({ step1: ["B"] })

      # Can continue answering
      restored.answer("details")
      expect(restored.current_step_id).to eq(:step3)
    end

    it "restores finished engine" do
      original = FlowEngine::Engine.new(definition)
      original.answer(["A"])
      state = original.to_state

      restored = FlowEngine::Engine.from_state(definition, state)
      expect(restored.finished?).to be true
      expect(restored.current_step).to be_nil
    end

    it "handles string keys from JSON round-trip" do
      state = {
        "current_step_id" => "step2",
        "answers" => { "step1" => ["B"] },
        "history" => %w[step1 step2]
      }

      restored = FlowEngine::Engine.from_state(definition, state)
      expect(restored.current_step_id).to eq(:step2)
      expect(restored.answers).to eq({ step1: ["B"] })
      expect(restored.history).to eq(%i[step1 step2])
    end

    it "handles nil current_step_id (finished)" do
      state = {
        "current_step_id" => nil,
        "answers" => { "step1" => ["A"] },
        "history" => ["step1"]
      }

      restored = FlowEngine::Engine.from_state(definition, state)
      expect(restored.finished?).to be true
    end

    it "round-trips through JSON serialization" do
      original = FlowEngine::Engine.new(definition)
      original.answer(["B"])
      original.answer("some text")

      json = JSON.generate(original.to_state)
      parsed = JSON.parse(json)

      restored = FlowEngine::Engine.from_state(definition, parsed)
      expect(restored.current_step_id).to eq(:step3)
      expect(restored.answers).to eq({ step1: ["B"], step2: "some text" })
      expect(restored.history).to eq(%i[step1 step2 step3])
    end
  end
end
