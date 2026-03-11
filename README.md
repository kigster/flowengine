# FlowEngine

[![RSpec](https://github.com/kigster/flowengine/actions/workflows/rspec.yml/badge.svg)](https://github.com/kigster/flowengine/actions/workflows/rspec.yml) &nbsp; [![RuboCop](https://github.com/kigster/flowengine/actions/workflows/rubocop.yml/badge.svg)](https://github.com/kigster/flowengine/actions/workflows/rubocop.yml) &nbsp; ![Coverage](docs/badges/coverage_badge.svg)

A declarative flow engine for building rules-driven wizards and intake forms in pure Ruby. Define multi-step flows as **directed graphs** with **conditional branching**, evaluate transitions using an **AST-based rule system**, and collect structured answers through a **stateful runtime engine** — all without framework dependencies.

> [!CAUTION]
> **This is not a form builder.** It's a *Form Definition Engine* that separates flow logic, data schema, and UI rendering into independent concerns.

## Installation

```ruby
gem "flowengine"
```

## Quick Start

```ruby
require "flowengine"

definition = FlowEngine.define do
  start :name

  step :name do
    type :text
    question "What is your name?"
    transition to: :age
  end

  step :age do
    type :number
    question "How old are you?"
    transition to: :beverage, if_rule: greater_than(:age, 20)
    transition to: :thanks
  end

  step :beverage do
    type :single_select
    question "Pick a drink."
    options %w[Beer Wine Cocktail]
    transition to: :thanks
  end

  step :thanks do
    type :text
    question "Thank you for your responses!"
  end
end

engine = FlowEngine::Engine.new(definition)
engine.answer("Alice")       # :name    -> :age
engine.answer(25)            # :age     -> :beverage  (25 > 20)
engine.answer("Wine")        # :beverage -> :thanks
engine.answer("ok")          # :thanks  -> finished

engine.finished?  # => true
engine.answers    # => { name: "Alice", age: 25, beverage: "Wine", thanks: "ok" }
engine.history    # => [:name, :age, :beverage, :thanks]
```

If Alice were 18, the engine skips `:beverage` entirely — the first matching transition (`18 NOT > 20`) falls through to the unconditional `:thanks`.

---

## The DSL

### Defining a Flow

Every flow starts with `FlowEngine.define`, which returns a **frozen, immutable** `Definition`:

```ruby
definition = FlowEngine.define do
  start :first_step

  # Optional: one-shot LLM pre-fill (see "Introduction" section)
  introduction label: "Describe your situation",
               placeholder: "Type here...",
               maxlength: 2000

  step :first_step do
    type :text
    question "What is your name?"
    transition to: :second_step
  end
end
```

### Step Configuration

| Method | Purpose | Example |
|--------|---------|---------|
| `type` | Input type (for UI adapters) | `:text`, `:number`, `:single_select`, `:multi_select`, `:number_matrix`, `:ai_intake` |
| `question` | Prompt shown to the user | `"What is your filing status?"` |
| `options` | Available choices (select types) | `%w[W2 1099 Business]` |
| `fields` | Named fields (matrix types) | `%w[RealEstate SCorp LLC]` |
| `decorations` | Opaque UI metadata | `{ hint: "metadata" }` |
| `transition` | Where to go next (with optional condition) | `transition to: :next, if_rule: equals(:field, "val")` |
| `visible_if` | Visibility rule (DAG mode) | `visible_if contains(:income, "Rental")` |
| `max_clarifications` | Max follow-up rounds for `:ai_intake` steps | `max_clarifications 3` |

### Transitions

Evaluated **in order** — the first matching transition wins. A transition with no `if_rule:` always matches (use as fallback):

```ruby
step :income_types do
  type :multi_select
  question "Select income types."
  options %w[W2 1099 Business Investment Rental]

  transition to: :business_count,     if_rule: contains(:income_types, "Business")
  transition to: :investment_details, if_rule: contains(:income_types, "Investment")
  transition to: :state_filing  # unconditional fallback
end
```

### Visibility Rules

Steps can have visibility conditions for DAG-mode rendering:

```ruby
step :spouse_income do
  type :number
  question "What is your spouse's annual income?"
  visible_if equals(:filing_status, "married_filing_jointly")
  transition to: :deductions
end
```

## Rule System

Rules are **immutable AST objects** — composable and evaluated polymorphically.

### Atomic Rules

| Helper | Evaluates |
|--------|-----------|
| `contains(:field, "val")` | `Array(answers[:field]).include?("val")` |
| `equals(:field, "val")` | `answers[:field] == "val"` |
| `greater_than(:field, 10)` | `answers[:field].to_i > 10` |
| `less_than(:field, 5)` | `answers[:field].to_i < 5` |
| `not_empty(:field)` | `answers[:field]` is not nil and not empty |

### Composite Rules

```ruby
# AND — all must be true
transition to: :special, if_rule: all(
  equals(:status, "married"),
  contains(:income, "Business"),
  greater_than(:business_count, 2)
)

# OR — at least one must be true
transition to: :alt, if_rule: any(
  contains(:income, "Investment"),
  contains(:income, "Rental")
)

# Nest arbitrarily
transition to: :complex, if_rule: all(
  equals(:status, "married"),
  any(greater_than(:biz_count, 3), contains(:income, "Rental")),
  not_empty(:dependents)
)
```

## Engine API

```ruby
engine = FlowEngine::Engine.new(definition)
```

| Method | Returns | Description |
|--------|---------|-------------|
| `current_step_id` | `Symbol?` | Current step ID |
| `current_step` | `Node?` | Current Node object |
| `answer(value)` | `nil` | Records answer and advances |
| `finished?` | `Boolean` | True when no more steps |
| `answers` | `Hash` | All collected `{ step_id => value }` |
| `history` | `Array<Symbol>` | Visited step IDs in order |
| `definition` | `Definition` | The immutable flow definition |
| `submit_introduction(text, llm_client:)` | `nil` | One-shot LLM pre-fill from free-form text |
| `submit_ai_intake(text, llm_client:)` | `ClarificationResult` | Multi-round AI intake for current `:ai_intake` step |
| `submit_clarification(text, llm_client:)` | `ClarificationResult` | Continue an active AI intake conversation |
| `introduction_text` | `String?` | Raw introduction text submitted |
| `clarification_round` | `Integer` | Current AI intake round (0 if none active) |
| `conversation_history` | `Array<Hash>` | AI intake conversation `[{role:, text:}]` |
| `to_state` / `.from_state` | `Hash` / `Engine` | State serialization for persistence |

### Error Handling

```ruby
engine.answer("extra")                        # AlreadyFinishedError (flow finished)
definition.step(:nonexistent)                 # UnknownStepError
engine.submit_introduction("SSN: 123-45-6789", llm_client:) # SensitiveDataError
engine.submit_introduction("A" * 3000, llm_client:)         # ValidationError (maxlength)
engine.submit_ai_intake("hi", llm_client:)    # EngineError (not on an ai_intake step)
```

---

## LLM Integration

FlowEngine offers two ways to use LLMs for pre-filling answers from free-form text.

### LLM Adapters & Configuration

The gem ships with three adapters (all via [`ruby_llm`](https://github.com/crmne/ruby_llm)):

| Adapter | Env Variable |
|---------|-------------|
| `AnthropicAdapter` | `ANTHROPIC_API_KEY` |
| `OpenAIAdapter` | `OPENAI_API_KEY` |
| `GeminiAdapter` | `GEMINI_API_KEY` |

The file [`resources/models.yml`](resources/models.yml) defines three model tiers per vendor (`top`, `default`, `fastest`). Override with `$FLOWENGINE_LLM_MODELS_PATH`.

```yaml
models:
  vendors:
    anthropic:
      var: "ANTHROPIC_API_KEY"
      top: "claude-opus-4-6"
      default: "claude-sonnet-4-6"
      fastest: "claude-haiku-4-5-20251001"
    openai:
      var: "OPENAI_API_KEY"
      top: "gpt-5.4"
      default: "gpt-5-mini"
      fastest: "gpt-5-nano"
    gemini:
      var: "GEMINI_API_KEY"
      top: "gemini-3.1-pro-preview"
      default: "gemini-2.5-flash"
      fastest: "gemini-2.5-flash-lite"
```

```ruby
# Auto-detect from environment (checks Anthropic > OpenAI > Gemini)
client = FlowEngine::LLM.auto_client

# Explicit provider / model override
client = FlowEngine::LLM.auto_client(anthropic_api_key: "sk-ant-...", model: "claude-haiku-4-5-20251001")

# Manual adapter
adapter = FlowEngine::LLM::Adapters::OpenAIAdapter.new(api_key: ENV["OPENAI_API_KEY"])
client = FlowEngine::LLM::Client.new(adapter: adapter, model: "gpt-5-mini")
```

### Sensitive Data Protection

Before any text reaches the LLM, `SensitiveDataFilter` scans for SSN, ITIN, EIN, and nine-consecutive-digit patterns. If detected, a `SensitiveDataError` is raised immediately — no LLM call is made.

---

### Option 1: Introduction (One-Shot Pre-Fill)

A flow-level free-form text field parsed by the LLM in a single pass. Good for simple intake where one prompt is enough.

```ruby
definition = FlowEngine.define do
  start :filing_status

  introduction label: "Tell us about your tax situation",
               placeholder: "e.g. I am married, filing jointly, with 2 dependents...",
               maxlength: 2000

  step :filing_status do
    type :single_select
    question "What is your filing status?"
    options %w[single married_filing_jointly head_of_household]
    transition to: :dependents
  end

  step :dependents do
    type :number
    question "How many dependents?"
  end
end

engine = FlowEngine::Engine.new(definition)
engine.submit_introduction(
  "I am married filing jointly with 2 dependents",
  llm_client: FlowEngine::LLM.auto_client
)
engine.answers   # => { filing_status: "married_filing_jointly", dependents: 2 }
engine.finished? # => true
```

---

### Option 2: AI Intake Steps (Multi-Round Conversational)

An `:ai_intake` step type that supports multi-round clarification. Place them anywhere in the flow — including multiple times. The LLM extracts answers for downstream steps and can ask follow-up questions.

```ruby
definition = FlowEngine.define do
  start :personal_intake

  # AI intake: collects info for the steps that follow
  step :personal_intake do
    type :ai_intake
    question "Tell us about yourself and your tax situation"
    max_clarifications 2  # up to 2 follow-up rounds (0 = one-shot)
    transition to: :filing_status
  end

  step :filing_status do
    type :single_select
    question "What is your filing status?"
    options %w[single married_joint married_separate head_of_household]
    transition to: :dependents
  end

  step :dependents do
    type :number
    question "How many dependents do you claim?"
    transition to: :income_types
  end

  step :income_types do
    type :multi_select
    question "Select all income types that apply"
    options %w[W2 1099 Business Investment Rental]
  end
end
```

#### Running an AI Intake

```ruby
engine = FlowEngine::Engine.new(definition)
client = FlowEngine::LLM.auto_client

# Round 1: initial submission
result = engine.submit_ai_intake(
  "I'm married filing jointly, 2 kids, W2 and business income",
  llm_client: client
)
result.done?          # => false (LLM wants to ask more)
result.follow_up      # => "Which state do you primarily reside in?"
result.round          # => 1
result.pending_steps  # => [:income_types] (steps still unanswered)
engine.answers        # => { filing_status: "married_joint", dependents: 2 }

# Round 2: respond to follow-up
result = engine.submit_clarification(
  "California. W2 from my job and a small LLC.",
  llm_client: client
)
result.done?  # => true (no more follow-ups or max reached)
engine.answers[:income_types]  # => ["W2", "Business"]

# Engine auto-advances past all pre-filled steps
engine.finished?  # => true
```

#### ClarificationResult

Each `submit_ai_intake` / `submit_clarification` call returns a `ClarificationResult`:

| Attribute | Type | Description |
|-----------|------|-------------|
| `answered` | `Hash` | Step answers filled this round |
| `pending_steps` | `Array<Symbol>` | Steps still unanswered |
| `follow_up` | `String?` | LLM's follow-up question, or `nil` if done |
| `round` | `Integer` | Current round number (1-based) |
| `done?` | `Boolean` | True when `follow_up` is nil |

When `max_clarifications` is reached, the intake finalizes even if the LLM wanted to ask more. Unanswered steps are presented normally to the user.

#### Multiple AI Intakes in One Flow

Place `:ai_intake` steps at multiple points to break up the conversation:

```ruby
definition = FlowEngine.define do
  start :personal_intake

  step :personal_intake do
    type :ai_intake
    question "Tell us about yourself and your tax situation"
    max_clarifications 2
    transition to: :filing_status
  end

  step :filing_status do
    # ... personal info steps ...
    transition to: :financial_intake
  end

  # Second AI intake mid-flow
  step :financial_intake do
    type :ai_intake
    question "Describe your financial situation: accounts, debts, investments"
    max_clarifications 3
    transition to: :annual_income
  end

  step :annual_income do
    # ... financial steps ...
  end
end
```

Each `:ai_intake` step maintains its own conversation history and round counter. State is fully serializable for persistence between requests.

### Custom LLM Adapters

```ruby
class MyAdapter < FlowEngine::LLM::Adapter
  def initialize(api_key:)
    super()
    @api_key = api_key
  end

  def chat(system_prompt:, user_prompt:, model:)
    # Must return response text (expected to be JSON)
  end
end
```

---

## State Persistence

The engine's full state — including AI intake conversation history — can be serialized and restored:

```ruby
state = engine.to_state
# => { current_step_id: :income_types, answers: { ... }, history: [...],
#      introduction_text: "...", clarification_round: 1,
#      conversation_history: [{role: :user, text: "..."}, ...],
#      active_intake_step_id: :personal_intake }

restored = FlowEngine::Engine.from_state(definition, state)
```

Round-trips through JSON (string keys) are handled automatically.

## Validation

Pluggable validators via the adapter pattern. Ships with `NullAdapter` (always passes):

```ruby
class MyValidator < FlowEngine::Validation::Adapter
  def validate(node, input)
    errors = []
    errors << "must be a number" if node.type == :number && !input.is_a?(Numeric)
    FlowEngine::Validation::Result.new(valid: errors.empty?, errors: errors)
  end
end

engine = FlowEngine::Engine.new(definition, validator: MyValidator.new)
```

## Mermaid Diagram Export

```ruby
exporter = FlowEngine::Graph::MermaidExporter.new(definition)
puts exporter.export
```

## Architecture

![architecture](docs/floweingine-architecture.png)

The core has **zero UI logic**, **zero DB logic**, and **zero framework dependencies**. Adapters translate input/output, persist state, and render UI.

| Component | Responsibility |
|-----------|---------------|
| `FlowEngine.define` | DSL entry point; returns a frozen `Definition` |
| `Definition` | Immutable flow graph (nodes + start step + introduction) |
| `Node` | Single step: type, question, options/fields, transitions, visibility |
| `Transition` | Directed edge with optional rule condition |
| `Rules::*` | AST nodes for conditional logic |
| `Evaluator` | Evaluates rules against the answer store |
| `Engine` | Stateful runtime: current step, answers, history, AI intake state |
| `ClarificationResult` | Immutable result from an AI intake round |
| `Introduction` | Immutable config for one-shot introduction (label, placeholder, maxlength) |
| `Validation::Adapter` | Interface for pluggable validation |
| `LLM::Client` | High-level: builds prompt, calls adapter, parses JSON |
| `LLM::Adapter` | Abstract LLM API interface (Anthropic, OpenAI, Gemini implementations) |
| `LLM::SensitiveDataFilter` | Rejects text containing SSN, ITIN, EIN patterns |
| `Graph::MermaidExporter` | Exports flow as a Mermaid diagram |

## Ecosystem

| Gem | Purpose |
|-----|---------|
| **`flowengine`** (this gem) | Core engine + LLM integration (depends on `ruby_llm`) |
| **`flowengine-cli`** | Terminal wizard via [TTY Toolkit](https://ttytoolkit.org/) + Dry::CLI |
| **`flowengine-rails`** | Rails Engine with ActiveRecord persistence and web views |

## Development

```bash
bundle install
just test    # RSpec + RuboCop
just lint    # RuboCop only
just doc     # Generate YARD docs
```

## License

MIT License. See [LICENSE](https://opensource.org/licenses/MIT).
