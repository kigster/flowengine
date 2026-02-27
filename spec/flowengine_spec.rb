# frozen_string_literal: true

RSpec.describe FlowEngine do
  it "has a version number" do
    expect(FlowEngine::VERSION).not_to be_nil
  end

  it "has version 0.1.0" do
    expect(FlowEngine::VERSION).to eq("0.1.0")
  end

  describe ".define" do
    it "returns a frozen Definition" do
      definition = FlowEngine.define do
        start :step1

        step :step1 do
          type :text
          question "Hello?"
        end
      end

      expect(definition).to be_a(FlowEngine::Definition)
      expect(definition).to be_frozen
    end

    it "raises when no start step is defined" do
      expect do
        FlowEngine.define do
          step :step1 do
            type :text
            question "Hello?"
          end
        end
      end.to raise_error(FlowEngine::DefinitionError, /No start step defined/)
    end

    it "raises when no steps are defined" do
      expect do
        FlowEngine.define do
          start :step1
        end
      end.to raise_error(FlowEngine::DefinitionError, /No steps defined/)
    end
  end
end
