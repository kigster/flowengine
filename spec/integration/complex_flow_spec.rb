# frozen_string_literal: true

require "json"
require_relative "../fixtures/complex_tax_intake"

RSpec.describe "Complex Tax Intake Flow Integration" do
  let(:definition) { COMPLEX_TAX_INTAKE }

  describe "maximum path: visits nearly every step" do
    it "completes the full complex path with all income types, foreign accounts, and high charitable giving" do
      engine = FlowEngine::Engine.new(definition)

      # Step 1: filing_status
      expect(engine.current_step_id).to eq(:filing_status)
      engine.answer("married_filing_jointly")

      # Step 2: dependents
      expect(engine.current_step_id).to eq(:dependents)
      engine.answer(3)

      # Step 3: income_types - select all major types to trigger maximum branching
      expect(engine.current_step_id).to eq(:income_types)
      engine.answer(%w[W2 1099 Business Investment Rental Retirement])

      # Step 4: business_count - more than 2 to trigger complex_business_info
      expect(engine.current_step_id).to eq(:business_count)
      engine.answer(4)

      # Step 5: complex_business_info
      expect(engine.current_step_id).to eq(:complex_business_info)
      engine.answer("EIN: 12-3456789. Entities: Alpha LLC, Beta SCorp, Gamma LLC, Delta CCorp")

      # Step 6: business_details
      expect(engine.current_step_id).to eq(:business_details)
      engine.answer({ "RealEstate" => 1, "SCorp" => 1, "CCorp" => 1, "Trust" => 0, "LLC" => 2 })

      # Step 7: investment_details (because income_types contains "Investment")
      expect(engine.current_step_id).to eq(:investment_details)
      engine.answer(%w[Stocks Bonds Crypto RealEstate])

      # Step 8: crypto_details (because investment_details contains "Crypto")
      expect(engine.current_step_id).to eq(:crypto_details)
      engine.answer("Coinbase and Kraken, approximately 150 transactions in 2025")

      # Step 9: rental_details (because income_types contains "Rental")
      expect(engine.current_step_id).to eq(:rental_details)
      engine.answer({ "Residential" => 2, "Commercial" => 1, "Vacation" => 0 })

      # Step 10: state_filing
      expect(engine.current_step_id).to eq(:state_filing)
      engine.answer(%w[California NewYork])

      # Step 11: foreign_accounts - yes to trigger foreign_account_details
      expect(engine.current_step_id).to eq(:foreign_accounts)
      engine.answer("yes")

      # Step 12: foreign_account_details
      expect(engine.current_step_id).to eq(:foreign_account_details)
      engine.answer(3)

      # Step 13: deduction_types - include Charitable to trigger charitable_amount
      expect(engine.current_step_id).to eq(:deduction_types)
      engine.answer(%w[Medical Charitable Education Mortgage])

      # Step 14: charitable_amount - over 5000 to trigger charitable_documentation
      expect(engine.current_step_id).to eq(:charitable_amount)
      engine.answer(12_000)

      # Step 15: charitable_documentation
      expect(engine.current_step_id).to eq(:charitable_documentation)
      engine.answer("Red Cross: $5,000; Habitat for Humanity: $4,000; Local Food Bank: $3,000")

      # Step 16: contact_info
      expect(engine.current_step_id).to eq(:contact_info)
      engine.answer("Jane Smith, jane.smith@example.com, 555-123-4567")

      # Step 17: review
      expect(engine.current_step_id).to eq(:review)
      engine.answer("confirm")

      # Verify completion
      expect(engine.finished?).to be true

      expected_history = %i[
        filing_status dependents income_types
        business_count complex_business_info business_details
        investment_details crypto_details rental_details
        state_filing foreign_accounts foreign_account_details
        deduction_types charitable_amount charitable_documentation
        contact_info review
      ]
      expect(engine.history).to eq(expected_history)
      expect(engine.history.length).to eq(17)

      # Verify key answers are present
      expect(engine.answers).to include(
        filing_status: "married_filing_jointly",
        dependents: 3,
        income_types: %w[W2 1099 Business Investment Rental Retirement],
        business_count: 4,
        foreign_accounts: "yes",
        foreign_account_details: 3,
        charitable_amount: 12_000,
        contact_info: "Jane Smith, jane.smith@example.com, 555-123-4567",
        review: "confirm"
      )

      # Build and output JSON result
      result = {
        flow_name: "complex_tax_intake",
        scenario: "maximum_path",
        path_taken: engine.history,
        answers: engine.answers,
        steps_visited: engine.history.length,
        completed_at: Time.now.iso8601
      }

      json_output = JSON.pretty_generate(result)

      output_path = File.join(__dir__, "..", "fixtures", "complex_flow_output.json")
      File.write(output_path, json_output)

      puts "\n\n=== Complex Tax Intake Flow Result (Maximum Path) ===\n#{json_output}\n=== End Result ===\n\n"
    end
  end

  describe "minimum path: single filer, W2 only, no special deductions" do
    it "completes the shortest path through the flow" do
      engine = FlowEngine::Engine.new(definition)

      # Step 1: filing_status
      expect(engine.current_step_id).to eq(:filing_status)
      engine.answer("single")

      # Step 2: dependents
      expect(engine.current_step_id).to eq(:dependents)
      engine.answer(0)

      # Step 3: income_types - W2 only, no special income types
      expect(engine.current_step_id).to eq(:income_types)
      engine.answer(["W2"])

      # Skips business, investment, rental -> goes straight to state_filing
      # Step 4: state_filing
      expect(engine.current_step_id).to eq(:state_filing)
      engine.answer(["Texas"])

      # Step 5: foreign_accounts - no
      expect(engine.current_step_id).to eq(:foreign_accounts)
      engine.answer("no")

      # Skips foreign_account_details -> goes to deduction_types
      # Step 6: deduction_types - None
      expect(engine.current_step_id).to eq(:deduction_types)
      engine.answer(["None"])

      # Skips charitable_amount -> goes to contact_info
      # Step 7: contact_info
      expect(engine.current_step_id).to eq(:contact_info)
      engine.answer("John Doe, john.doe@example.com, 555-987-6543")

      # Step 8: review
      expect(engine.current_step_id).to eq(:review)
      engine.answer("confirm")

      # Verify completion
      expect(engine.finished?).to be true

      expected_history = %i[
        filing_status dependents income_types
        state_filing foreign_accounts deduction_types
        contact_info review
      ]
      expect(engine.history).to eq(expected_history)
      expect(engine.history.length).to eq(8)

      expect(engine.answers).to include(
        filing_status: "single",
        dependents: 0,
        income_types: ["W2"],
        contact_info: "John Doe, john.doe@example.com, 555-987-6543"
      )

      # Verify skipped steps are NOT in history
      expect(engine.history).not_to include(:business_count)
      expect(engine.history).not_to include(:business_details)
      expect(engine.history).not_to include(:investment_details)
      expect(engine.history).not_to include(:rental_details)
      expect(engine.history).not_to include(:crypto_details)
      expect(engine.history).not_to include(:complex_business_info)
      expect(engine.history).not_to include(:foreign_account_details)
      expect(engine.history).not_to include(:charitable_amount)
      expect(engine.history).not_to include(:charitable_documentation)

      result = {
        flow_name: "complex_tax_intake",
        scenario: "minimum_path",
        path_taken: engine.history,
        answers: engine.answers,
        steps_visited: engine.history.length,
        completed_at: Time.now.iso8601
      }

      json_output = JSON.pretty_generate(result)
      puts "\n\n=== Complex Tax Intake Flow Result (Minimum Path) ===\n#{json_output}\n=== End Result ===\n\n"
    end
  end

  describe "medium path: married, business + investment income, no rentals, no foreign accounts" do
    it "completes a medium-length path with business and investment branches" do
      engine = FlowEngine::Engine.new(definition)

      # Step 1: filing_status
      expect(engine.current_step_id).to eq(:filing_status)
      engine.answer("married_filing_separately")

      # Step 2: dependents
      expect(engine.current_step_id).to eq(:dependents)
      engine.answer(1)

      # Step 3: income_types - Business + Investment (no Rental)
      expect(engine.current_step_id).to eq(:income_types)
      engine.answer(%w[W2 Business Investment])

      # Step 4: business_count - exactly 2 (not > 2, so no complex_business_info)
      expect(engine.current_step_id).to eq(:business_count)
      engine.answer(2)

      # Skips complex_business_info -> goes to business_details
      # Step 5: business_details
      expect(engine.current_step_id).to eq(:business_details)
      engine.answer({ "RealEstate" => 0, "SCorp" => 1, "CCorp" => 0, "Trust" => 0, "LLC" => 1 })

      # Step 6: investment_details (because income_types contains "Investment")
      expect(engine.current_step_id).to eq(:investment_details)
      engine.answer(%w[Stocks Bonds MutualFunds])

      # No Crypto selected -> skips crypto_details
      # No Rental in income_types -> skips rental_details -> goes to state_filing
      # Step 7: state_filing
      expect(engine.current_step_id).to eq(:state_filing)
      engine.answer(%w[California Illinois])

      # Step 8: foreign_accounts - no
      expect(engine.current_step_id).to eq(:foreign_accounts)
      engine.answer("no")

      # Step 9: deduction_types - Charitable + Mortgage but low charitable
      expect(engine.current_step_id).to eq(:deduction_types)
      engine.answer(%w[Charitable Mortgage])

      # Step 10: charitable_amount - under 5000, no documentation needed
      expect(engine.current_step_id).to eq(:charitable_amount)
      engine.answer(3000)

      # Skips charitable_documentation -> goes to contact_info
      # Step 11: contact_info
      expect(engine.current_step_id).to eq(:contact_info)
      engine.answer("Alice Johnson, alice.j@example.com, 555-555-0100")

      # Step 12: review
      expect(engine.current_step_id).to eq(:review)
      engine.answer("confirm")

      # Verify completion
      expect(engine.finished?).to be true

      expected_history = %i[
        filing_status dependents income_types
        business_count business_details investment_details
        state_filing foreign_accounts deduction_types
        charitable_amount contact_info review
      ]
      expect(engine.history).to eq(expected_history)
      expect(engine.history.length).to eq(12)

      # Verify specific branching outcomes
      expect(engine.history).to include(:business_count, :business_details, :investment_details)
      expect(engine.history).not_to include(:complex_business_info)
      expect(engine.history).not_to include(:crypto_details)
      expect(engine.history).not_to include(:rental_details)
      expect(engine.history).not_to include(:foreign_account_details)
      expect(engine.history).not_to include(:charitable_documentation)

      expect(engine.answers).to include(
        filing_status: "married_filing_separately",
        dependents: 1,
        income_types: %w[W2 Business Investment],
        business_count: 2,
        charitable_amount: 3000
      )

      result = {
        flow_name: "complex_tax_intake",
        scenario: "medium_path",
        path_taken: engine.history,
        answers: engine.answers,
        steps_visited: engine.history.length,
        completed_at: Time.now.iso8601
      }

      json_output = JSON.pretty_generate(result)
      puts "\n\n=== Complex Tax Intake Flow Result (Medium Path) ===\n#{json_output}\n=== End Result ===\n\n"
    end
  end

  describe "edge case: head_of_household with rental only and foreign accounts" do
    it "skips business and investment branches but visits rental and foreign account paths" do
      engine = FlowEngine::Engine.new(definition)

      engine.answer("head_of_household")
      expect(engine.current_step_id).to eq(:dependents)

      engine.answer(2)
      expect(engine.current_step_id).to eq(:income_types)

      engine.answer(%w[1099 Rental])
      # No Business, no Investment -> goes to rental_details
      expect(engine.current_step_id).to eq(:rental_details)

      engine.answer({ "Residential" => 1, "Commercial" => 0, "Vacation" => 1 })
      expect(engine.current_step_id).to eq(:state_filing)

      engine.answer(["Florida"])
      expect(engine.current_step_id).to eq(:foreign_accounts)

      engine.answer("yes")
      expect(engine.current_step_id).to eq(:foreign_account_details)

      engine.answer(1)
      expect(engine.current_step_id).to eq(:deduction_types)

      engine.answer(%w[Medical Education])
      # No Charitable -> skips charitable_amount
      expect(engine.current_step_id).to eq(:contact_info)

      engine.answer("Bob Lee, bob@example.com, 555-000-1111")
      expect(engine.current_step_id).to eq(:review)

      engine.answer("confirm")
      expect(engine.finished?).to be true

      expected_history = %i[
        filing_status dependents income_types
        rental_details state_filing foreign_accounts
        foreign_account_details deduction_types contact_info review
      ]
      expect(engine.history).to eq(expected_history)
      expect(engine.history.length).to eq(10)

      # Verify rental-specific answers
      expect(engine.answers[:rental_details]).to eq({
                                                      "Residential" => 1,
                                                      "Commercial" => 0,
                                                      "Vacation" => 1
                                                    })
      expect(engine.answers[:foreign_accounts]).to eq("yes")
      expect(engine.answers[:foreign_account_details]).to eq(1)

      result = {
        flow_name: "complex_tax_intake",
        scenario: "rental_and_foreign_accounts",
        path_taken: engine.history,
        answers: engine.answers,
        steps_visited: engine.history.length,
        completed_at: Time.now.iso8601
      }

      json_output = JSON.pretty_generate(result)
      puts "\n\n=== Complex Tax Intake Flow Result (Rental + Foreign) ===\n#{json_output}\n=== End Result ===\n\n"
    end
  end

  describe "rule type coverage" do
    it "exercises less_than and any rules in combination with the flow" do
      # This test verifies that the rule types work correctly with the flow engine
      # by testing specific rule evaluations that the flow depends on
      engine = FlowEngine::Engine.new(definition)

      # Drive to business_count step
      engine.answer("single")
      engine.answer(0)
      engine.answer(%w[Business])
      expect(engine.current_step_id).to eq(:business_count)

      # Answer 1 business (less_than 2, and NOT greater_than 2)
      engine.answer(1)
      # Should go to business_details (not complex_business_info)
      expect(engine.current_step_id).to eq(:business_details)
      expect(engine.history).not_to include(:complex_business_info)

      engine.answer({ "LLC" => 1 })
      # No Investment or Rental -> state_filing
      expect(engine.current_step_id).to eq(:state_filing)
    end

    it "tests the all rule with filing status and business count together" do
      # Build a custom definition that uses all, any, less_than, not_empty
      all_rules_definition = FlowEngine.define do
        start :status

        step :status do
          type :single_select
          question "Filing status?"
          options %w[single married]
          transition to: :dependents
        end

        step :dependents do
          type :number
          question "How many dependents?"
          transition to: :income
        end

        step :income do
          type :multi_select
          question "Income types?"
          options %w[W2 Business]
          transition to: :special_review,
                     if_rule: all(
                       equals(:status, "married"),
                       contains(:income, "Business"),
                       not_empty(:income)
                     )
          transition to: :alt_review,
                     if_rule: any(
                       less_than(:dependents, 2),
                       contains(:income, "W2")
                     )
          transition to: :default_review
        end

        step :special_review do
          type :text
          question "Married with business income - special review"
        end

        step :alt_review do
          type :text
          question "Alternative review path"
        end

        step :default_review do
          type :text
          question "Default review"
        end
      end

      # Test the all() rule path: married, Business + W2, not_empty
      engine1 = FlowEngine::Engine.new(all_rules_definition)
      engine1.answer("married")
      engine1.answer(0)
      engine1.answer(%w[W2 Business])
      expect(engine1.current_step_id).to eq(:special_review)

      # Test the any() rule path: single, W2 only (contains W2 matches)
      engine2 = FlowEngine::Engine.new(all_rules_definition)
      engine2.answer("single")
      engine2.answer(0)
      engine2.answer(["W2"])
      expect(engine2.current_step_id).to eq(:alt_review)

      # Test the any() rule path via less_than: single, Business only, dependents < 2
      engine3 = FlowEngine::Engine.new(all_rules_definition)
      engine3.answer("single")
      engine3.answer(1)
      engine3.answer(["Business"])
      # less_than(:dependents, 2) => 1 < 2 => true, so any() matches -> alt_review
      expect(engine3.current_step_id).to eq(:alt_review)

      # Test default path: single, Business only, dependents >= 2 (no W2, not less_than 2)
      engine4 = FlowEngine::Engine.new(all_rules_definition)
      engine4.answer("single")
      engine4.answer(3)
      engine4.answer(["Business"])
      # all() fails (not married), any() fails (dependents=3 not < 2, no W2) -> default
      expect(engine4.current_step_id).to eq(:default_review)
    end
  end

  describe "Mermaid diagram export" do
    it "exports the complex flow as a valid Mermaid diagram" do
      exporter = FlowEngine::Graph::MermaidExporter.new(definition)
      mermaid_output = exporter.export

      # Write to file
      output_path = File.join(__dir__, "..", "fixtures", "complex_flow_diagram.mmd")
      File.write(output_path, mermaid_output)

      puts "\n\n=== Mermaid Diagram ===\n#{mermaid_output}\n=== End Diagram ===\n\n"

      # Verify structure
      expect(mermaid_output).to start_with("flowchart TD")

      # Verify all 17 steps appear
      %i[
        filing_status dependents income_types
        business_count complex_business_info business_details
        investment_details crypto_details rental_details
        state_filing foreign_accounts foreign_account_details
        deduction_types charitable_amount charitable_documentation
        contact_info review
      ].each do |step_id|
        expect(mermaid_output).to include(step_id.to_s)
      end

      # Verify conditional edges include rule labels
      expect(mermaid_output).to include("Business in income_types")
      expect(mermaid_output).to include("Investment in income_types")
      expect(mermaid_output).to include("Rental in income_types")
      expect(mermaid_output).to include("Crypto in investment_details")
      expect(mermaid_output).to include("foreign_accounts == yes")
      expect(mermaid_output).to include("business_count > 2")
      expect(mermaid_output).to include("charitable_amount > 5000")
      expect(mermaid_output).to include("Charitable in deduction_types")

      # Verify unconditional edges exist (no label)
      expect(mermaid_output).to include("filing_status --> dependents")
      expect(mermaid_output).to include("contact_info --> review")
    end
  end
end
