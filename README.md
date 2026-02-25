# JsonLiveviewRender

An agent-safe generative UI framework for Phoenix LiveView.

JsonLiveviewRender implements the **Catalog -> Spec -> Render** pattern:

1. Define a typed component catalog.
2. Have an LLM generate a flat JSON spec constrained to that catalog.
3. Validate and render the spec server-side with LiveView.

## v0.1 Scope

- Catalog DSL (`JsonLiveviewRender.Catalog`)
- Spec validation (`JsonLiveviewRender.Spec`)
- Registry mapping (`JsonLiveviewRender.Registry`)
- LiveView renderer (`JsonLiveviewRender.Renderer`)
- Permission filtering + binding resolution
- JSON Schema + prompt export (`JsonLiveviewRender.Schema`)

Out of scope in v0.1:

- Provider streaming integrations/adapters
- Expression runtime (`$state`, `$cond`)
- Cross-platform adapters (Slack/Teams/WhatsApp)

Experimental now (pre-v0.3):

- Structured stream accumulator (`JsonLiveviewRender.Stream`) with `{:root, id}`, `{:element, id, element}`, `{:finalize}` events

## Installation

Add `json_liveview_render` to your dependencies:

```elixir
def deps do
  [
    {:json_liveview_render, "~> 0.1.0"}
  ]
end
```

## Quickstart

Bootstrap starter files in an existing Phoenix project:

```elixir
mix json_liveview_render.new --module MyApp
```

This generates starter catalog/registry/component/authorizer modules under `lib/my_app/json_liveview_render/`
plus `priv/json_liveview_render/example_spec.json`.

Manual setup example:

```elixir
defmodule MyApp.UICatalog do
  use JsonLiveviewRender.Catalog

  component :metric do
    description "Single KPI"
    prop :label, :string, required: true
    prop :value, :string, required: true
  end
end

defmodule MyApp.UIRegistry do
  use JsonLiveviewRender.Registry, catalog: MyApp.UICatalog

  render :metric, &MyAppWeb.Components.metric/1
end
```

Validate and render:

```elixir
case JsonLiveviewRender.Spec.validate(spec, MyApp.UICatalog) do
  {:ok, _spec} ->
    # in HEEx:
    # <JsonLiveviewRender.Renderer.render
    #   spec={@spec}
    #   catalog={MyApp.UICatalog}
    #   registry={MyApp.UIRegistry}
    #   bindings={@bindings}
    #   current_user={@current_user}
    #   authorizer={MyApp.JsonLiveviewRender.Authorizer}
    # />

  {:error, reasons} ->
    Logger.warning("Invalid spec: #{inspect(reasons)}")
end
```

## Compatibility

- Elixir >= 1.15
- Phoenix >= 1.8
- Phoenix LiveView >= 1.1

## Development Checks

Run the v0.1 verification gate:

```elixir
mix ci
```

This runs formatting, compile with warnings-as-errors, and tests (including scaffold smoke coverage).

## Learnings

- See [LEARNINGS.md](./LEARNINGS.md) for implementation learnings and follow-up risks.

## Debugging Specs

Use `JsonLiveviewRender.Debug.inspect_spec/3` to validate and inspect topology details for a spec:

```elixir
{:ok, report} = JsonLiveviewRender.Debug.inspect_spec(spec, MyApp.UICatalog)
```

## License

MIT
