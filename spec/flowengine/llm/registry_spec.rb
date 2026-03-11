# frozen_string_literal: true

require "rspec"
require "rspec/its"

RSpec.describe FlowEngine::LLM, "adapter registry" do
  before { described_class.reset! }

  after { described_class.reset! }

  describe ".load!" do
    context "when an API key is available" do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY", nil).and_return("test-key")
        allow(ENV).to receive(:fetch).with("OPENAI_API_KEY", nil).and_return(nil)
        allow(ENV).to receive(:fetch).with("GEMINI_API_KEY", nil).and_return(nil)

        # Stub RubyLLM configure since we don't want real API calls
        allow(RubyLLM).to receive(:configure).and_yield(double("config").as_null_object)
      end

      it "loads adapters for vendors with API keys" do
        expect { described_class.load! }.to output(/Loaded 3 adapters/).to_stderr
      end

      it "warns about missing vendor keys" do
        expect { described_class.load! }.to output(/openai.*not found|gemini.*not found/i).to_stderr
      end

      it "registers adapters by vendor and qualifier" do
        silence_warnings { described_class.load! }

        adapter = described_class[vendor: :anthropic, qualifier: :default]
        expect(adapter).to be_a(FlowEngine::LLM::Adapter)
        expect(adapter.qualifier).to eq(:default)
      end

      it "registers top, default, and fastest qualifiers" do
        silence_warnings { described_class.load! }

        %i[top default fastest].each do |q|
          expect(described_class[vendor: :anthropic, qualifier: q]).not_to be_nil
        end
      end

      it "skips loading on subsequent calls" do
        silence_warnings { described_class.load! }
        # Second call should be a no-op (no output)
        expect { described_class.load! }.not_to output.to_stderr
      end
    end

    context "when models file does not exist" do
      it "raises ConfigurationError" do
        expect do
          described_class.load!("/nonexistent/models.yml")
        end.to raise_error(FlowEngine::Errors::ConfigurationError, /not found/)
      end
    end

    context "when no API keys are available" do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with("ANTHROPIC_API_KEY", nil).and_return(nil)
        allow(ENV).to receive(:fetch).with("OPENAI_API_KEY", nil).and_return(nil)
        allow(ENV).to receive(:fetch).with("GEMINI_API_KEY", nil).and_return(nil)
      end

      it "loads zero adapters" do
        expect { described_class.load! }.to output(/Loaded 0 adapters/).to_stderr
      end
    end
  end

  describe ".[]" do
    it "returns nil for unloaded vendor" do
      expect(described_class[vendor: :anthropic]).to be_nil
    end
  end

  describe ".reset!" do
    it "clears all adapters" do
      described_class.reset!
      expect(described_class[vendor: :anthropic]).to be_nil
    end
  end

  private

  def silence_warnings(&)
    $stderr = StringIO.new
    yield
  ensure
    $stderr = STDERR
  end
end
