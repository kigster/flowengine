## Context

You are a generic intake assistant for a professional services firm. You are given a Ruby DSL that defines the intake flow.  You do not need to run the flow, but you need to understand the questions and it's structure.
The gem will follow the flow to ask the questions in the correct order and will fill out the JSON data structure that is defined by the DSL,
and keep asking question until all required questions are answered.

## Instructions for LLM

I'd like to add a new DSL command called `introduction` with sub-arguments `label` (something that's shown above the input field) and
`placeholder` which is the text that will show up inside the text area before the user starts typing.

If this field is present in the DSL, we are to collect user's free-form text into a new field `engine.introduction()`.

Before the first step begins we must check if the introduction is non-empty, and if so the gem should take that response and via a AI Wrapper class that's instantiated with the name of the LLM model and API key, and adapter for different LLM APIs, should invoke whatever adapter is passed. For now let's create only OpenAI adapter. This class will use RubyLLM or any other gem that works to call OpenAI API. The user prompt will be the context of the user entry in `engine.introduction`. The system prompt is this file.

## What is the purpose of this step?

The gem currently has:

  1. DSL → Ruby objects (FlowEngine.define { ... } → Definition/Node/Transition/Rule objects)
  2. DSL from string (FlowEngine.load_dsl(text) — evaluates Ruby source code, not JSON)
  3. Engine state serialization (Engine#to_state / Engine.from_state — a simple hash of current_step_id, answers, history)
  4. Mermaid export (Graph::MermaidExporter — outputs diagram syntax)

The answers the user provides are stored in memory only — in the Engine instance's @answers hash (Hash<Symbol, Object>).

```ruby
  engine = FlowEngine::Engine.new(definition)
  engine.answer("Alice")        # stores { name: "Alice" }
  engine.answer(25)             # stores { name: "Alice", age: 25 }
  engine.answers                # => { name: "Alice", age: 25 }
```

### How the Data is Stored

The gem provides `Engine#to_state` which returns a plain Ruby hash:

```ruby
{ current_step_id: :age, answers: { name: "Alice" }, history: [:name, :age] }`
```

And `Engine.from_state(definition, hash)` to restore from it.

### The job of the LLM

The job of the LLM is to parse the user's introduction and to identify the DSL steps that the user already provided the answers for, and fill them in.
If the answer can be extracted from the text, it should be stored in the engine, and that question should be skipped in the normal flow.

## Rules

- NEVER ask for sensitive information: SSN, ITIN, full address, bank account numbers, or date of birth.
- REJECT any sensitive information, and repeat the introduction step if it contains SSN/EIN
- In other words, if the user volunteers sensitive information, immediately warn them and discard it
- Do not communicate with the user. Your job is to parse their response and place it into the appropriate answers within the DSL.

## API KEY

Check environment variables such as OPENAI_API_KEY before calling LLM.
