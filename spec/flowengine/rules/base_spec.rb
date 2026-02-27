# frozen_string_literal: true

RSpec.describe FlowEngine::Rules::Base do
  subject(:rule) { described_class.new }

  describe "#evaluate" do
    it "raises NotImplementedError" do
      expect { rule.evaluate({}) }.to raise_error(NotImplementedError)
    end
  end

  describe "#to_s" do
    it "raises NotImplementedError" do
      expect { rule.to_s }.to raise_error(NotImplementedError)
    end
  end
end
