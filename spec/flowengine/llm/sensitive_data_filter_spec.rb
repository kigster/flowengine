# frozen_string_literal: true

RSpec.describe FlowEngine::LLM::SensitiveDataFilter do
  describe ".check!" do
    context "with clean text" do
      it "does not raise for normal introduction text" do
        expect { described_class.check!("I am married filing jointly with 2 dependents") }.not_to raise_error
      end

      it "does not raise for text with short numbers" do
        expect { described_class.check!("I have 3 businesses and 2 rental properties") }.not_to raise_error
      end
    end

    context "with SSN pattern (XXX-XX-XXXX)" do
      it "raises SensitiveDataError" do
        expect { described_class.check!("My SSN is 123-45-6789") }
          .to raise_error(FlowEngine::SensitiveDataError, /SSN/)
      end
    end

    context "with ITIN pattern (9XX-XX-XXXX)" do
      it "raises SensitiveDataError" do
        expect { described_class.check!("My ITIN is 912-34-5678") }
          .to raise_error(FlowEngine::SensitiveDataError, /ITIN/)
      end
    end

    context "with EIN pattern (XX-XXXXXXX)" do
      it "raises SensitiveDataError" do
        expect { described_class.check!("Business EIN: 12-3456789") }
          .to raise_error(FlowEngine::SensitiveDataError, /EIN/)
      end
    end

    context "with nine consecutive digits" do
      it "raises SensitiveDataError" do
        expect { described_class.check!("My number is 123456789") }
          .to raise_error(FlowEngine::SensitiveDataError, %r{SSN/ITIN})
      end
    end

    context "with multiple sensitive patterns" do
      it "reports all detected types" do
        text = "SSN: 123-45-6789, EIN: 12-3456789"
        expect { described_class.check!(text) }
          .to raise_error(FlowEngine::SensitiveDataError, /SSN.*EIN|EIN.*SSN/)
      end
    end
  end
end
