# frozen_string_literal: true

RSpec.describe FlowEngine::Introduction do
  subject(:intro) { described_class.new(label: "Tell us about yourself", placeholder: "Type here...") }

  it { is_expected.to be_frozen }

  its(:label) { is_expected.to eq("Tell us about yourself") }
  its(:placeholder) { is_expected.to eq("Type here...") }

  its(:maxlength) { is_expected.to be_nil }

  context "with default placeholder" do
    subject(:intro) { described_class.new(label: "Describe your situation") }

    its(:placeholder) { is_expected.to eq("") }
  end

  context "with maxlength" do
    subject(:intro) { described_class.new(label: "Brief intro", maxlength: 500) }

    its(:maxlength) { is_expected.to eq(500) }
  end
end
