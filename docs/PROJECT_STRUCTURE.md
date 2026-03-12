# Project Structure

```text
lib/flowengine/
  flowengine.rb              # Module entry: define() and load_dsl()
  version.rb                 # VERSION = "0.3.1"
  errors.rb                  # Error hierarchy (8 classes)
  clarification_result.rb    # Data.define for AI intake round results
  introduction.rb            # Data.define(:label, :placeholder, :maxlength)
  definition.rb              # Immutable flow graph container
  node.rb                    # Single flow step (question, type, transitions, max_clarifications)
  transition.rb              # Directed edge with optional rule condition
  evaluator.rb               # Rule evaluation against answers
  engine.rb                  # Runtime session (answers, history, navigation, AI intake state)
  engine/
    state_serializer.rb      # Symbolizes string-keyed state from JSON round-trips
  dsl/
    flow_builder.rb          # FlowEngine.define {} context (start, introduction, step)
    step_builder.rb          # step {} block builder (includes max_clarifications)
    rule_helpers.rb          # contains(), equals(), all(), any(), etc.
  rules/
    base.rb                  # Abstract rule (evaluate + to_s)
    contains.rb              # Array.include? semantics
    equals.rb                # Simple equality
    greater_than.rb          # Numeric > comparison (coerces to_i)
    less_than.rb             # Numeric < comparison (coerces to_i)
    not_empty.rb             # !nil && !empty?
    all.rb                   # Composite AND
    any.rb                   # Composite OR
  validation/
    adapter.rb               # Abstract validator interface
    null_adapter.rb          # No-op default validator
  llm/
    adapter.rb               # Abstract LLM adapter interface
    adapters.rb              # Requires all concrete adapters
    auto_client.rb           # FlowEngine::LLM.auto_client factory
    provider.rb              # Provider/model registry from models.yml
    client.rb                # High-level LLM client (prompt building + response parsing)
    system_prompt_builder.rb # Builds system prompt for introduction pre-fill
    intake_prompt_builder.rb # Builds system prompt for AI intake steps
    sensitive_data_filter.rb # Rejects SSN, ITIN, EIN patterns
  graph/
    mermaid_exporter.rb      # Exports Definition to Mermaid diagram
resources/
  models.yml                 # Vendor/model registry (Anthropic, OpenAI, Gemini)
  prompts/
    generic-dsl-intake.j2    # Static system prompt template for LLM parsing
spec/
  flowengine_spec.rb         # Top-level define/load_dsl tests
  flowengine/                # Mirrors lib/ structure
    engine_spec.rb           # Core engine tests
    engine_ai_intake_spec.rb # AI intake step tests
    engine_introduction_spec.rb # Introduction pre-fill tests
    engine_state_spec.rb     # State persistence tests
    clarification_result_spec.rb
    llm/                     # LLM adapter, client, filter, prompt builder specs
  integration/
    introduction_flow_spec.rb # Introduction + LLM pre-fill integration
    multi_ai_intake_spec.rb  # Multi-AI intake integration test
    tax_intake_flow_spec.rb  # Real-world tax intake example
    complex_flow_spec.rb     # Complex branching tests
  fixtures/
    complex_tax_intake.rb    # 17-step tax intake flow definition
```
