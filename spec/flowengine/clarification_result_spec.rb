# frozen_string_literal: true

require "rspec"
require "rspec/its"

RSpec.describe FlowEngine::ClarificationResult do
  describe "with follow-up" do
    subject(:result) do
      described_class.new(
        answered: { filing_status: "single" },
        pending_steps: %i[dependents income_types],
        follow_up: "How many dependents do you have?",
        round: 1
      )
    end

    it { is_expected.to be_frozen }
    its(:answered) { is_expected.to eq(filing_status: "single") }
    its(:pending_steps) { is_expected.to eq(%i[dependents income_types]) }
    its(:follow_up) { is_expected.to eq("How many dependents do you have?") }
    its(:round) { is_expected.to eq(1) }
    its(:done?) { is_expected.to be false }
  end

  describe "when done (no follow-up)" do
    subject(:result) do
      described_class.new(
        answered: { filing_status: "single", dependents: 0 },
        pending_steps: [],
        follow_up: nil,
        round: 2
      )
    end

    its(:done?) { is_expected.to be true }
    its(:follow_up) { is_expected.to be_nil }
  end

  describe "defaults" do
    subject(:result) { described_class.new }

    its(:answered) { is_expected.to eq({}) }
    its(:pending_steps) { is_expected.to eq([]) }
    its(:follow_up) { is_expected.to be_nil }
    its(:round) { is_expected.to eq(1) }
    its(:done?) { is_expected.to be true }
  end
end
