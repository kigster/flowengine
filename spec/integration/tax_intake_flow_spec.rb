# frozen_string_literal: true

RSpec.describe "Tax Intake Flow Integration" do
  let(:definition) do
    FlowEngine.define do
      start :earnings

      step :earnings do
        type :multi_select
        question "What are your main types of earnings in 2025?"
        options %w[W2 1099 BusinessOwnership Dividends Rental]
        transition to: :business_details, if_rule: contains(:earnings, "BusinessOwnership")
        transition to: :w2_details, if_rule: contains(:earnings, "W2")
        transition to: :summary
      end

      step :business_details do
        type :number_matrix
        question "How many of the following business types do you own?"
        fields %w[RealEstate SCorp CCorp Trust LLC]
        transition to: :w2_details, if_rule: contains(:earnings, "W2")
        transition to: :summary
      end

      step :w2_details do
        type :number_matrix
        question "How many W2s do you have?"
        fields %w[W2Count]
        transition to: :summary
      end

      step :summary do
        type :text
        question "Thank you! Here is your summary."
      end
    end
  end

  describe "path: BusinessOwnership + W2" do
    it "goes through earnings -> business_details -> w2_details -> summary" do
      engine = FlowEngine::Engine.new(definition)

      expect(engine.current_step_id).to eq(:earnings)
      engine.answer(%w[W2 BusinessOwnership])

      expect(engine.current_step_id).to eq(:business_details)
      engine.answer({ "SCorp" => 1, "LLC" => 2 })

      expect(engine.current_step_id).to eq(:w2_details)
      engine.answer({ "W2Count" => 3 })

      expect(engine.current_step_id).to eq(:summary)
      engine.answer("acknowledged")

      expect(engine.finished?).to be true
      expect(engine.history).to eq(%i[earnings business_details w2_details summary])
      expect(engine.answers).to eq({
                                     earnings: %w[W2 BusinessOwnership],
                                     business_details: { "SCorp" => 1, "LLC" => 2 },
                                     w2_details: { "W2Count" => 3 },
                                     summary: "acknowledged"
                                   })
    end
  end

  describe "path: W2 only" do
    it "goes through earnings -> w2_details -> summary" do
      engine = FlowEngine::Engine.new(definition)

      engine.answer(["W2"])
      expect(engine.current_step_id).to eq(:w2_details)

      engine.answer({ "W2Count" => 2 })
      expect(engine.current_step_id).to eq(:summary)

      engine.answer("done")
      expect(engine.finished?).to be true
      expect(engine.history).to eq(%i[earnings w2_details summary])
    end
  end

  describe "path: Dividends only (no conditional match for first two transitions)" do
    it "goes through earnings -> summary" do
      engine = FlowEngine::Engine.new(definition)

      engine.answer(["Dividends"])
      expect(engine.current_step_id).to eq(:summary)

      engine.answer("done")
      expect(engine.finished?).to be true
      expect(engine.history).to eq(%i[earnings summary])
    end
  end

  describe "path: BusinessOwnership only (no W2)" do
    it "goes through earnings -> business_details -> summary" do
      engine = FlowEngine::Engine.new(definition)

      engine.answer(["BusinessOwnership"])
      expect(engine.current_step_id).to eq(:business_details)

      engine.answer({ "SCorp" => 1 })
      expect(engine.current_step_id).to eq(:summary)

      engine.answer("done")
      expect(engine.finished?).to be true
      expect(engine.history).to eq(%i[earnings business_details summary])
    end
  end

  describe "Mermaid export of tax flow" do
    it "produces valid Mermaid syntax" do
      exporter = FlowEngine::Graph::MermaidExporter.new(definition)
      output = exporter.export

      expect(output).to include("flowchart TD")
      expect(output).to include("earnings")
      expect(output).to include("business_details")
      expect(output).to include("w2_details")
      expect(output).to include("summary")
      expect(output).to include("BusinessOwnership in earnings")
      expect(output).to include("W2 in earnings")
    end
  end

  describe "complex rules" do
    let(:complex_definition) do
      FlowEngine.define do
        start :marital_status

        step :marital_status do
          type :single_select
          question "What is your marital status?"
          options %w[Single Married]
          transition to: :income
        end

        step :income do
          type :number_matrix
          question "What is your total income?"
          fields %w[TotalIncome]
          transition to: :high_income_married,
                     if_rule: all(
                       equals(:marital_status, "Married"),
                       greater_than(:income, 100_000)
                     )
          transition to: :standard_filing
        end

        step :high_income_married do
          type :text
          question "You qualify for joint filing optimization."
        end

        step :standard_filing do
          type :text
          question "Standard filing path."
        end
      end
    end

    it "routes to high_income_married for married with high income" do
      engine = FlowEngine::Engine.new(complex_definition)

      engine.answer("Married")
      expect(engine.current_step_id).to eq(:income)

      engine.answer(150_000)
      expect(engine.current_step_id).to eq(:high_income_married)
    end

    it "routes to standard_filing for single with high income" do
      engine = FlowEngine::Engine.new(complex_definition)

      engine.answer("Single")
      engine.answer(150_000)
      expect(engine.current_step_id).to eq(:standard_filing)
    end

    it "routes to standard_filing for married with low income" do
      engine = FlowEngine::Engine.new(complex_definition)

      engine.answer("Married")
      engine.answer(50_000)
      expect(engine.current_step_id).to eq(:standard_filing)
    end
  end
end
