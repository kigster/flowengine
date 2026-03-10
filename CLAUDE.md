# FlowEngine

A pure Ruby, framework-agnostic gem providing a declarative DSL for building rules-driven wizards and intake forms. Separates flow logic, data schema, and UI rendering into independent concerns.

**Version**: 0.2.0 | **License**: MIT | **Ruby**: >= 4.0.1

## Quick Reference

```bash
just test           # Run RSpec + RuboCop
just lint           # RuboCop only
just format         # RuboCop auto-correct + auto-gen config
just doc            # Generate YARD docs and open browser
just clean          # Remove pkg/ and coverage/
just setup          # Install Ruby via rbenv + bundle install
just check-all      # lint + test
```

## Project Structure

```
lib/flowengine/
  flowengine.rb              # Module entry: define() and load_dsl()
  version.rb                 # VERSION = "0.2.0"
  errors.rb                  # Error hierarchy (8 classes)
  introduction.rb            # Data.define(:label, :placeholder, :maxlength)
  definition.rb              # Immutable flow graph container
  node.rb                    # Single flow step (question, type, transitions)
  transition.rb              # Directed edge with optional rule condition
  evaluator.rb               # Rule evaluation against answers
  engine.rb                  # Runtime session (answers, history, navigation, introduction)
  dsl/
    flow_builder.rb          # FlowEngine.define {} context (start, introduction, step)
    step_builder.rb          # step {} block builder
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
    openai_adapter.rb        # OpenAI adapter via ruby_llm gem
    anthropic_adapter.rb     # Anthropic/Claude adapter via ruby_llm gem
    gemini_adapter.rb        # Google Gemini adapter via ruby_llm gem
    client.rb                # High-level LLM client (prompt building + response parsing)
    system_prompt_builder.rb # Builds system prompt from Definition + static template
    sensitive_data_filter.rb # Rejects SSN, ITIN, EIN patterns
  graph/
    mermaid_exporter.rb      # Exports Definition to Mermaid diagram
resources/
  prompts/
    generic-dsl-intake.j2    # Static system prompt template for LLM introduction parsing
spec/
  flowengine_spec.rb         # Top-level define/load_dsl tests
  flowengine/                # Mirrors lib/ structure
    llm/                     # LLM adapter, client, filter, prompt builder specs
  integration/
    introduction_flow_spec.rb # Introduction + LLM pre-fill integration test
    tax_intake_flow_spec.rb  # Real-world tax intake example
    complex_flow_spec.rb     # Complex branching tests
  fixtures/
    complex_tax_intake.rb    # 17-step tax intake flow definition
```

## Architecture

### Core Classes

| Class | Role | Mutable? |
|---|---|---|
| `FlowEngine` (module) | Entry point: `define(&block)`, `load_dsl(text)` | N/A |
| `Introduction` | DSL config: label, placeholder, maxlength for free-form intro text | Frozen |
| `Definition` | Immutable flow graph (start_step_id + nodes + introduction) | Frozen |
| `Node` | Single step: id, type, question, options, fields, transitions, visibility_rule | Frozen |
| `Transition` | Directed edge: target step + optional rule | Frozen |
| `Engine` | Runtime session: current_step, answers, history, introduction_text | Mutable |
| `Rules::Base` | Abstract rule: `evaluate(answers) -> bool`, `to_s` | Frozen |
| `Validation::Adapter` | Abstract validator interface | - |
| `LLM::Adapter` | Abstract LLM adapter: `chat(system_prompt:, user_prompt:, model:)` | - |
| `LLM::OpenAIAdapter` | OpenAI adapter via ruby_llm gem | - |
| `LLM::AnthropicAdapter` | Anthropic/Claude adapter via ruby_llm gem | - |
| `LLM::GeminiAdapter` | Google Gemini adapter via ruby_llm gem | - |
| `LLM::Client` | High-level: builds prompt, calls adapter, parses JSON response | - |
| `LLM::SystemPromptBuilder` | Builds system prompt from Definition + static template | - |
| `LLM::SensitiveDataFilter` | Rejects text containing SSN, ITIN, EIN patterns | - |
| `Graph::MermaidExporter` | Exports Definition to Mermaid flowchart syntax | - |

### Error Hierarchy

```text
FlowEngine::Error < StandardError
  DefinitionError          # Invalid flow definition
  UnknownStepError         # Step id not found
  LLMError                 # LLM-related errors (missing key, parse failure)
  EngineError              # Runtime errors
    AlreadyFinishedError   # answer() called after flow ended
    ValidationError        # Validator rejected answer / maxlength exceeded
    SensitiveDataError     # Introduction contains SSN, ITIN, EIN, etc.
```

### Data Flow

```text
DSL block -> FlowBuilder -> StepBuilder(s) -> Definition (frozen, includes Introduction config)
                                                   |
                                              Engine (runtime)
                                                   |
                             submit_introduction() -> filter sensitive data -> LLM parse -> pre-fill answers -> auto-advance
                                                   |
                                          answer() -> validate -> store -> advance
```

### Key Design Patterns

1. **Immutability**: Definition, Node, Transition, all Rule objects are frozen after creation
2. **Builder pattern**: FlowBuilder + StepBuilder with instance_eval for readable DSL
3. **AST pattern**: Rules form an expression tree evaluated polymorphically
4. **Adapter pattern**: Validation::Adapter for pluggable validators
5. **First-match-wins**: Transitions evaluated in order; first matching rule determines next step
6. **State serialization**: Engine#to_state / Engine.from_state for session/DB persistence
7. **LLM adapter pattern**: LLM::Adapter for pluggable LLM providers (OpenAI, Anthropic, etc.)
8. **Introduction pre-fill**: LLM parses free-form text to pre-fill answers and auto-advance

## DSL Reference

```ruby
definition = FlowEngine.define do
  start :first_step

  # Optional: collect free-form text before the flow starts, parsed by LLM
  introduction label: "Tell us about your situation",
               placeholder: "Describe your needs in your own words...",
               maxlength: 2000

  step :first_step do
    type :multi_select
    question "What applies?"
    options %w[A B C]
    fields %w[Field1 Field2]          # for matrix-style steps
    decorations({ hint: "metadata" }) # opaque to engine, for UI

    # Transitions (first match wins; last should be unconditional fallback)
    transition to: :branch_a, if_rule: contains(:first_step, "A")
    transition to: :branch_b, if_rule: equals(:first_step, "B")
    transition to: :fallback

    # Visibility (optional, for DAG mode)
    visible_if not_empty(:some_step)
  end
end
```

### Rule Helpers

| Helper | Rule Class | Semantics |
|---|---|---|
| `contains(field, value)` | Rules::Contains | `answers[field].include?(value)` |
| `equals(field, value)` | Rules::Equals | `answers[field] == value` |
| `greater_than(field, n)` | Rules::GreaterThan | `answers[field].to_i > n` |
| `less_than(field, n)` | Rules::LessThan | `answers[field].to_i < n` |
| `not_empty(field)` | Rules::NotEmpty | `!answers[field].nil? && !empty?` |
| `all(*rules)` | Rules::All | AND: all rules must be true |
| `any(*rules)` | Rules::Any | OR: at least one rule must be true |

### Engine Usage

```ruby
engine = FlowEngine::Engine.new(definition)

# Optional: submit introduction text for LLM pre-filling
adapter = FlowEngine::LLM::OpenAIAdapter.new(api_key: ENV["OPENAI_API_KEY"])
client = FlowEngine::LLM::Client.new(adapter: adapter, model: "gpt-4o-mini")
engine.submit_introduction("I am married with 2 kids, W2 and business income", llm_client: client)
# Pre-filled steps are auto-advanced; engine.current_step_id is now the first unanswered step

engine.answer("some value")     # validates, stores, advances
engine.current_step             # => Node or nil
engine.current_step_id          # => Symbol or nil
engine.finished?                # => Boolean
engine.answers                  # => { step_id: value, ... }
engine.history                  # => [:step1, :step2, ...]
engine.introduction_text        # => String or nil

# Persistence (includes introduction_text)
state = engine.to_state
restored = FlowEngine::Engine.from_state(definition, state)
```

## Ecosystem

- **flowengine** (this gem): Core engine, no external dependencies
- **flowengine-cli**: Terminal UI adapter (TTY Toolkit)
- **flowengine-rails**: Rails engine with ActiveRecord + web views

## Code Style

- **Ruby 4.0+** target
- **frozen_string_literal: true** on every file
- **Double quotes** for strings
- **120 char** line length max
- **20 line** method length max
- No block length limit in specs
- Documentation cop disabled (Style/Documentation: false)
- Uses `rspec-its` gem for property testing
- RSpec: documentation format, color, random order
- Single production dependency: `ruby_llm` (for LLM introduction parsing)

## CI/CD

GitHub Actions on push to main + all PRs:

- **rspec.yml**: `bundle exec rspec --format documentation -p 2` on Ruby 4.0.1
- **rubocop.yml**: `bundle exec rubocop` on Ruby 4.0.1

## Testing Conventions

- Test files mirror lib/ structure under spec/
- Integration tests in spec/integration/
- Fixtures in spec/fixtures/
- Use `rspec-its` for property testing: `its(:property) { is_expected.to ... }`
- SimpleCov for coverage (loaded in spec_helper)
- Complex tax intake fixture (17 steps) serves as primary integration test

## Adding a New Rule Type

1. Create `lib/flowengine/rules/my_rule.rb` inheriting from `Rules::Base`
2. Implement `#evaluate(answers)` returning boolean and `#to_s` for labels
3. Freeze the instance in initialize
4. Add `require_relative` in `lib/flowengine.rb`
5. Add helper method in `lib/flowengine/dsl/rule_helpers.rb`
6. Add specs in `spec/flowengine/rules/my_rule_spec.rb`

## LLM-parsed Introduction

The `introduction` DSL command enables collecting free-form text before the flow starts.
An LLM parses the text to pre-fill answers and auto-advance past answered steps.

### DSL

```ruby
introduction label: "Tell us about your tax situation",
             placeholder: "e.g. I am married, filing jointly, with 2 dependents...",
             maxlength: 2000  # optional character limit (nil = unlimited)
```

- `label` (required): shown above the text area
- `placeholder` (optional): ghost text inside the text area
- `maxlength` (optional): max characters; raises `ValidationError` if exceeded

The introduction config is stored on `Definition#introduction` (an `Introduction` Data object).

### Engine Integration

```ruby
# Auto-detect adapter from environment (checks ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY)
client = FlowEngine::LLM.auto_client

# Or explicitly choose a provider:
adapter = FlowEngine::LLM::AnthropicAdapter.new(api_key: ENV["ANTHROPIC_API_KEY"])
client = FlowEngine::LLM::Client.new(adapter: adapter, model: "claude-sonnet-4-20250514")

engine = FlowEngine::Engine.new(definition)
engine.submit_introduction("I am married with 2 kids, W2 income", llm_client: client)
engine.current_step_id  # => first step the LLM could NOT pre-fill
engine.introduction_text # => "I am married with 2 kids, W2 income"
```

`submit_introduction` flow:

1. Validates `maxlength` if set (raises `ValidationError`)
2. Scans for sensitive data patterns (raises `SensitiveDataError`)
3. Calls `LLM::Client#parse_introduction` which builds a system prompt from the Definition, calls the adapter, and parses the JSON response
4. Merges extracted answers into `engine.answers`
5. Auto-advances through all consecutively pre-filled steps

### LLM Adapter Pattern

```ruby
# Auto-detect: picks the first available key (Anthropic > OpenAI > Gemini)
client = FlowEngine::LLM.auto_client

# Or with explicit keys / model override:
client = FlowEngine::LLM.auto_client(anthropic_api_key: "sk-...", model: "claude-haiku-4-5-20251001")

# Abstract adapter — subclass and implement #chat
FlowEngine::LLM::Adapter

# Anthropic via ruby_llm gem (requires ANTHROPIC_API_KEY env var or explicit key)
FlowEngine::LLM::AnthropicAdapter.new(api_key: "sk-ant-...")

# OpenAI via ruby_llm gem (requires OPENAI_API_KEY env var or explicit key)
FlowEngine::LLM::OpenAIAdapter.new(api_key: "sk-...")

# Google Gemini via ruby_llm gem (requires GEMINI_API_KEY env var or explicit key)
FlowEngine::LLM::GeminiAdapter.new(api_key: "AIza...")

# Client wraps adapter + model
FlowEngine::LLM::Client.new(adapter: adapter, model: "claude-sonnet-4-20250514")
```

### Adding a New LLM Adapter

1. Create `lib/flowengine/llm/my_adapter.rb` inheriting from `LLM::Adapter`
2. Implement `#chat(system_prompt:, user_prompt:, model:)` returning response text (JSON)
3. Add `require_relative` in `lib/flowengine/llm.rb`
4. Add specs in `spec/flowengine/llm/my_adapter_spec.rb`

### Sensitive Data Filter

`LLM::SensitiveDataFilter.check!(text)` scans for and rejects:

- SSN: `\b\d{3}-\d{2}-\d{4}\b`
- ITIN: `\b9\d{2}-\d{2}-\d{4}\b`
- EIN: `\b\d{2}-\d{7}\b`
- Nine consecutive digits: `\b\d{9}\b`

Raises `SensitiveDataError` before the text reaches the LLM.

### System Prompt

Built by `LLM::SystemPromptBuilder` from:

1. Static template: `resources/prompts/generic-dsl-intake.j2`
2. Dynamic step metadata (id, type, question, options, fields) from the Definition
3. JSON response format instructions

### State Persistence

`introduction_text` is included in `Engine#to_state` and restored by `Engine.from_state`.
