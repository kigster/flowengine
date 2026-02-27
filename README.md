# Flowengine

> [!IMPORTANT]
>
> Gem's Responsibilities
>
> * DSL
> * Flow Definition
> * AST-based Rule system
> * Evaluator
> * Engine runtime
> * Validation adapter interface
> * Graph exporter (Mermaid)
> * Simulation runner
> * No ActiveRecord.
> * No Rails.
> * No terminal code.

### Proposed Gem Structure

```text
flowengine/
├── lib/
│   ├── flowengine.rb
│   ├── flowengine/
│   │   ├── definition.rb
│   │   ├── dsl.rb
│   │   ├── node.rb
│   │   ├── rule_ast.rb
│   │   ├── evaluator.rb
│   │   ├── engine.rb
│   │   ├── validation/
│   │   │   ├── adapter.rb
│   │   │   └── dry_validation_adapter.rb
│   │   ├── graph/
│   │   │   └── mermaid_exporter.rb
│   │   └── simulation.rb
├── exe/
│   └── flowengine
```

#### Core Concepts

Immutable structure representing flow graph.

```ruby
flowengine.define do
  start :earnings

  step :earnings do
    type :multi_select
    question "What are your main earnings?"
    options %w[W2 1099 BusinessOwnership]

    transition to: :business_details,
               if: contains(:earnings, "BusinessOwnership")
  end
end
```

Definition compiles DSL → Node objects → AST transitions.

No runtime state.

#### Engine (Pure Runtime)

```ruby
engine = flowengine::Engine.new(definition)

engine.current_step
engine.answer(value)
engine.finished?
engine.answers
```

Engine stores:

* current node id
* answer hash
* evaluator

No IO.

#### Rule AST (Clean & Extensible)

You want AST objects, not hash blobs.

```ruby
Contains.new(:earnings, "BusinessOwnership")
All.new(rule1, rule2)
Equals.new(:marital_status, "Married")
```

Evaluator does polymorphic dispatch:

```ruby
rule.evaluate(context)
```

Cleaner than giant case statements.

#### Validation (Dry Integration)

Adapter pattern:

```ruby
class DryValidationAdapter < Adapter
  def validate(step, input)
    step.schema.call(input)
  end
end
```

Core does:

```ruby
validator.validate(step, input)
```

IMPORTANT: Core does not depend directly on dry-validation.

#### Part 1b: CLI Layer (inside `flowengine-cli`)

CLI should be thin.

Use:

* dry-cli
* tty-prompt

NOTE: Dress up the CLI/Terminal interface a bit. Use as much of the TTY-Toolkit as needed.

#### Commands

```bash
flowengine run config.rb
flowengine graph config.rb --format=mermaid
flowengine simulate config.rb --answers=fixture.json
```

### Examples of Mermaid Charts

![Example](docs/flowengine-example.png)

<details>
  <summary>Expand to See Mermaid Sources</summary>

```mermaid
flowchart BT
    filing_status["What is your filing status for 2025?"] --> dependents["How many dependents do you have?"]
    dependents --> income_types["Select all income types that apply to you in 2025."]
    income_types -- Business in income_types --> business_count["How many total businesses do you own or are a part..."]
    income_types -- Investment in income_types --> investment_details["What types of investments do you hold?"]
    income_types -- Rental in income_types --> rental_details["Provide details about your rental properties."]
    income_types --> state_filing["Which states do you need to file in?"]
    business_count -- business_count > 2 --> complex_business_info["With more than 2 businesses, please provide your p..."]
    business_count --> business_details["How many of each business type do you own?"]
    complex_business_info --> business_details
    business_details -- Investment in income_types --> investment_details
    business_details -- Rental in income_types --> rental_details
    business_details --> state_filing
    investment_details -- Crypto in investment_details --> crypto_details["Please describe your cryptocurrency transactions (..."]
    investment_details -- Rental in income_types --> rental_details
    investment_details --> state_filing
    crypto_details -- Rental in income_types --> rental_details
    crypto_details --> state_filing
    rental_details --> state_filing
    state_filing --> foreign_accounts["Do you have any foreign financial accounts (bank a..."]
    foreign_accounts -- "foreign_accounts == yes" --> foreign_account_details["How many foreign accounts do you have?"]
    foreign_accounts --> deduction_types["Which additional deductions apply to you?"]
    foreign_account_details --> deduction_types
    deduction_types -- Charitable in deduction_types --> charitable_amount["What is your total estimated charitable contributi..."]
    deduction_types --> contact_info["Please provide your contact information (name, ema..."]
    charitable_amount -- charitable_amount > 5000 --> charitable_documentation["For charitable contributions over $5,000, please l..."]
    charitable_amount --> contact_info
    charitable_documentation --> contact_info
    contact_info --> review@{ label: "Thank you! Please review your information. Type 'c..." }

    review@{ shape: rect}
```

</details>
