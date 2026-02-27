# JsonLiveviewRender

An agent-safe generative UI framework for Phoenix LiveView.

JsonLiveviewRender implements the **Catalog -> Spec -> Render** pattern:

1. Define a typed component catalog.
2. Have an LLM generate a flat JSON spec constrained to that catalog.
3. Validate and render the spec server-side with LiveView.

## API Stability (PRD Contract)

JsonLiveviewRender tracks behavior by release family with an explicit v0.3 scope lock.

| Feature | v0.2 core (contract) | v0.3 candidate (locked) | Experimental / deferred |
| ------- | -------------------- | ------------------------ | --------------------- |
| Catalog (`JsonLiveviewRender.Catalog`) | ✅ In scope | | |
| Spec validator (`JsonLiveviewRender.Spec`) | ✅ In scope | | |
| Registry (`JsonLiveviewRender.Registry`) | ✅ In scope | | |
| Renderer (`JsonLiveviewRender.Renderer`) | ✅ In scope | | |
| Permissions (`JsonLiveviewRender.Permissions`) | ✅ In scope | | |
| Schema (`JsonLiveviewRender.Schema`) | ✅ In scope | | |
| Bindings (`JsonLiveviewRender.Bindings`) | ✅ In scope | | |
| Debug (`JsonLiveviewRender.Debug`) | ✅ In scope | | |
| Stream API (`JsonLiveviewRender.Stream`) | | ✅ In scope | |
| Partial validation/rendering (`validate_partial`, `allow_partial`) | | ✅ In scope | |
| Streaming adapters (`JsonLiveviewRender.Stream.Adapter.*`) | | | ✅ Deferred to companion package path |
| DevTools (`JsonLiveviewRender.DevTools`) | | | ✅ Experimental |
| Cross-platform / transport adapters (Slack/Teams/etc.) | | | ✅ Deferred |

Out of scope in v0.x core:

- Expression runtime (`$state`, `$cond`)
- Streaming transport adapter normalize layer (provider-specific, companion package surface)
- Cross-platform adapters (Slack/Teams/WhatsApp)
- `json_liveview_render` dev-only introspection in production

Feature matrix details are mirrored in `CHANGELOG.md`.

## Installation

Add `json_liveview_render` to your dependencies:

```elixir
def deps do
  [
    {:json_liveview_render, "~> 0.2"}
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

## Data Binding (v0.2 Core)

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

## Streaming (v0.3 candidate)

For incremental rendering, enable partial spec handling in the renderer while elements stream in:

```elixir
<JsonLiveviewRender.Renderer.render
  spec={@spec}
  catalog={MyApp.UICatalog}
  registry={MyApp.UIRegistry}
  bindings={@bindings}
  current_user={@current_user}
  allow_partial={true}
/>
```

Build specs progressively:

```elixir
stream = JsonLiveviewRender.Stream.new()

{:ok, stream} = JsonLiveviewRender.Stream.ingest(stream, {:root, "page"}, MyApp.UICatalog)
{:ok, stream} = JsonLiveviewRender.Stream.ingest(stream, {:element, "page", page_el}, MyApp.UICatalog)
{:ok, stream} = JsonLiveviewRender.Stream.ingest(stream, {:element, "metric_1", metric_el}, MyApp.UICatalog)
{:ok, stream} = JsonLiveviewRender.Stream.ingest(stream, {:finalize}, MyApp.UICatalog)

spec = JsonLiveviewRender.Stream.to_spec(stream)
{:ok, _validated_spec} = JsonLiveviewRender.Stream.finalize(stream, MyApp.UICatalog)
```

Provider adapter examples convert provider payloads into structured stream events:

```elixir
case JsonLiveviewRender.Stream.Adapter.OpenAI.normalize_event(provider_payload) do
  {:ok, event} ->
    JsonLiveviewRender.Stream.ingest(stream, event, MyApp.UICatalog)

  :ignore ->
    {:ok, stream}

  {:error, reason} ->
    {:error, reason}
end
```

## Experimental adapters and companion package features

The following adapter modules are shipped for experimentation and reference only:

- `JsonLiveviewRender.Stream.Adapter`
- `JsonLiveviewRender.Stream.Adapter.OpenAI`
- `JsonLiveviewRender.Stream.Adapter.Anthropic`

Streaming transport normalization is deferred to companion-package implementations for production integrations.

Use these modules only as reference patterns for provider-specific adapters.

## DevTools (Experimental)

Enable in-browser spec inspection while developing LiveViews:

```elixir
<JsonLiveviewRender.Renderer.render
  spec={@spec}
  catalog={MyApp.UICatalog}
  registry={MyApp.UIRegistry}
  bindings={@bindings}
  current_user={@current_user}
  dev_tools={true}
  dev_tools_enabled={Application.get_env(:json_liveview_render, :dev_tools_enabled, false)}
  dev_tools_open={true}
/>
```

This renders a `<details>` inspector with:

- input spec JSON
- rendered (permission-filtered) spec JSON
- validation status and errors for each view

Security by default:

- `dev_tools` is only rendered when:
  - `dev_tools` is `true`
  - `dev_tools_enabled` resolves to `true`
  - `dev_tools_force_disable` is `false`
  - `JsonLiveviewRender.DevTools` is present (for dev-only builds)

Recommended pattern:

```elixir
config :json_liveview_render, :dev_tools_enabled, Mix.env() == :dev

# Staging/QA debug opt-in:
config :json_liveview_render, :dev_tools_enabled, true
```

Then pass a single boolean guard from your app config:

```elixir
<JsonLiveviewRender.Renderer.render
  spec={@spec}
  catalog={MyApp.UICatalog}
  registry={MyApp.UIRegistry}
  bindings={@bindings}
  current_user={@current_user}
  dev_tools={@show_dev_tools}
  dev_tools_enabled={Application.get_env(:json_liveview_render, :dev_tools_enabled)}
  dev_tools_force_disable={Application.get_env(:json_liveview_render, :dev_tools_force_disable, false)}
/>
```

Set `@show_dev_tools` from your own environment switch if needed, and keep
`dev_tools_force_disable={true}` for extra hardening in sensitive pages.

## Compatibility

- Elixir >= 1.15
- Phoenix >= 1.8
- Phoenix LiveView >= 1.1

## Development Checks

Run the verification gate for this branch:

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
