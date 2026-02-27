# frozen_string_literal: true

RSpec.describe FlowEngine::DSL::RuleHelpers do
  let(:helper_class) { Class.new { include FlowEngine::DSL::RuleHelpers } }
  let(:helper) { helper_class.new }

  describe "#contains" do
    it "creates a Contains rule" do
      rule = helper.contains(:field, "value")
      expect(rule).to be_a(FlowEngine::Rules::Contains)
      expect(rule.field).to eq(:field)
      expect(rule.value).to eq("value")
    end
  end

  describe "#equals" do
    it "creates an Equals rule" do
      rule = helper.equals(:field, "value")
      expect(rule).to be_a(FlowEngine::Rules::Equals)
    end
  end

  describe "#greater_than" do
    it "creates a GreaterThan rule" do
      rule = helper.greater_than(:field, 10)
      expect(rule).to be_a(FlowEngine::Rules::GreaterThan)
    end
  end

  describe "#less_than" do
    it "creates a LessThan rule" do
      rule = helper.less_than(:field, 10)
      expect(rule).to be_a(FlowEngine::Rules::LessThan)
    end
  end

  describe "#not_empty" do
    it "creates a NotEmpty rule" do
      rule = helper.not_empty(:field)
      expect(rule).to be_a(FlowEngine::Rules::NotEmpty)
    end
  end

  describe "#all" do
    it "creates an All composite rule" do
      rule = helper.all(
        helper.contains(:a, "x"),
        helper.equals(:b, "y")
      )
      expect(rule).to be_a(FlowEngine::Rules::All)
      expect(rule.rules.length).to eq(2)
    end
  end

  describe "#any" do
    it "creates an Any composite rule" do
      rule = helper.any(
        helper.contains(:a, "x"),
        helper.equals(:b, "y")
      )
      expect(rule).to be_a(FlowEngine::Rules::Any)
      expect(rule.rules.length).to eq(2)
    end
  end
end
