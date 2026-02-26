# JsonLiveviewRender

An agent-safe generative UI framework for Phoenix LiveView.

JsonLiveviewRender implements the **Catalog -> Spec -> Render** pattern:

1. Define a typed component catalog.
2. Have an LLM generate a flat JSON spec constrained to that catalog.
3. Validate and render the spec server-side with LiveView.

## v0.2 Scope

- Catalog DSL (`JsonLiveviewRender.Catalog`)
- Spec validation (`JsonLiveviewRender.Spec`)
- Registry mapping (`JsonLiveviewRender.Registry`)
- LiveView renderer (`JsonLiveviewRender.Renderer`)
- Permission filtering + data binding (`*_binding`)
- JSON Schema + prompt export (`JsonLiveviewRender.Schema`)
- Local CI workflow (`./scripts/ci_local.sh`, `make ci-local`)

Out of scope in v0.2:

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
    {:json_liveview_render, "~> 0.2.0"}
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

## Data Binding (v0.2)

Props ending with `_binding` are resolved from the `bindings` assign at render time.

Example spec fragment:

```json
{
  "type": "data_table",
  "props": {
    "columns": [{"key": "id", "label": "Invoice #"}],
    "rows_binding": "overdue_invoices"
  }
}
```

At render time, `rows_binding: "overdue_invoices"` resolves to `bindings["overdue_invoices"]` and the component receives `rows: [...]`.

Enable optional runtime type checks for resolved binding values:

```elixir
<JsonLiveviewRender.Renderer.render
  spec={@spec}
  catalog={MyApp.UICatalog}
  registry={MyApp.UIRegistry}
  bindings={@bindings}
  current_user={@current_user}
  authorizer={MyApp.JsonLiveviewRender.Authorizer}
  check_binding_types={true}
/>
```

PubSub re-render pattern (documented; app-owned):

```elixir
def mount(_params, _session, socket) do
  Phoenix.PubSub.subscribe(MyApp.PubSub, "invoices:overdue")

  {:ok,
   assign(socket, :bindings, %{
     overdue_invoices: load_overdue_invoices()
   })}
end

def handle_info({:overdue_invoices_updated, rows}, socket) do
  {:noreply, update(socket, :bindings, &Map.put(&1, :overdue_invoices, rows))}
end
```

## Compatibility

- Elixir >= 1.15
- Phoenix >= 1.8
- Phoenix LiveView >= 1.1

## Development Checks

Run the v0.2 verification gate:

```elixir
mix ci
```

This runs formatting, compile with warnings-as-errors, and tests (including scaffold smoke coverage).

Run the same gate locally (without GitHub Actions):

```bash
./scripts/ci_local.sh
```

Or via make:

```bash
make ci-local
```

To mirror the CI version matrix locally, run the same command under both toolchains:

- Elixir `1.15.8` / OTP `26.2`
- Elixir `1.19.5` / OTP `28.0`

For `asdf`, that is typically:

```bash
asdf shell erlang 26.2
asdf shell elixir 1.15.8-otp-26
./scripts/ci_local.sh

asdf shell erlang 28.0
asdf shell elixir 1.19.5-otp-28
./scripts/ci_local.sh
```

## Learnings

- See [LEARNINGS.md](./LEARNINGS.md) for implementation learnings and follow-up risks.

## Debugging Specs

Use `JsonLiveviewRender.Debug.inspect_spec/3` to validate and inspect topology details for a spec:

```elixir
{:ok, report} = JsonLiveviewRender.Debug.inspect_spec(spec, MyApp.UICatalog)
```

## License

MIT
