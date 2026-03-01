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

## Permission Policy Examples

Configure component permissions in the catalog with `permission/1`:

- atom: legacy single-role policy
- list: shorthand for `any_of` semantics
- map: explicit composition with `:any_of`, `:all_of`, and optional `:deny`

```elixir
defmodule MyApp.UICatalog do
  use JsonLiveviewRender.Catalog

  component :admin_metrics do
    description "Admin-only view"
    prop :label, :string, required: true
    permission :admin
  end

  component :safe_card do
    description "Visible to members or admins"
    prop :title, :string, required: true
    permission [:member, :admin]
  end

  component :super_card do
    description "Requires multiple roles"
    prop :title, :string, required: true
    permission %{all_of: [:admin, :member]}
  end

  component :risky_card do
    description "Allowed except suspended users"
    prop :title, :string, required: true
    permission %{any_of: [:member, :admin], deny: [:suspended]}
  end
end
```

`current_user` can define effective roles and inheritance:

```elixir
current_user = %{
  roles: :admin,
  role_inheritance: %{admin: [:member]}
}
```

Current defaults for composition:

- list / `%{any_of: [...]}` uses permissive any-of logic
- `%{all_of: [...]}` requires all entries
- `:deny` is always evaluated before allow logic

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

The stream contract is:

- `{:root, id}`: establish the stream root
  - repeated `{:root, same_id}` is idempotent
  - repeated `{:root, different_id}` returns `{:error, {:root_already_set, ...}}`
- `{:element, id, element}`: add one element by id (only after a root is known)
  - repeated ids return `{:error, {:element_already_exists, ...}}`
- `{:finalize}`: mark stream completion
  - safe to call multiple times
- malformed sequencing returns explicit `{:error, reason}` and does not mutate stream state

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

### Adapter normalization reference patterns

Use the adapter modules to normalize provider payloads before calling `JsonLiveviewRender.Stream.ingest/4`.

- `:ignore` means the payload is unrelated noise and should be skipped.
- `{:error, {:invalid_adapter_event, reason}}` means the payload matched a supported provider tool surface but is malformed.

```elixir
case JsonLiveviewRender.Stream.Adapter.OpenAI.normalize_event(payload) do
  {:ok, event} ->
    JsonLiveviewRender.Stream.ingest(stream, event, Catalog)

  :ignore ->
    {:ok, stream}

  {:error, {:invalid_adapter_event, reason}} ->
    {:error, {:invalid_provider_payload, reason}}
end
```

Malformed payload behavior is intentionally strict and deterministic:

- missing required fields for a supported schema returns an explicit error
- unexpected argument shape returns an explicit schema error
- unrelated payloads remain noise and are ignored

These adapters are companion-surface references and should not be treated as in-scope v0.3 core transport behavior.

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

Recommended pattern (in compile-time config files like `config/dev.exs`):

```elixir
# config/dev.exs
config :json_liveview_render, :dev_tools_enabled, true

# config/prod.exs — not needed, false is the default
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

## Release Readiness Checklist (v0.3 gate)

Use [`RELEASE_READINESS.md`](RELEASE_READINESS.md) as the canonical release gate checklist and smoke matrix for v0.3 sign-off.

## Release Workflow

Use one canonical command before publishing a new Hex release:

```bash
make release-check
```

Before running release checks, prepare release notes in the [unreleased changelog template](CHANGELOG.md#unreleased-template):

- add in-progress items to `### Non-released`
- promote intentful entries to `### Release-ready`
- move `### Release-ready` content into a new version heading (`## X.Y.Z - YYYY-MM-DD`) before publishing and tag creation

For local iteration, release triggers, and tag policy, see [Release policy: local-first + tag policy](#release-policy-local-first--tag-policy).

This runs the required release-sanity sequence:

1. `mix json_liveview_render.check_metadata`
2. `mix format --check-formatted`
3. `mix compile --warnings-as-errors`
4. `MIX_PUBSUB=0 mix test`
5. `mix hex.publish --dry-run`

The command exits `0` only when all checks succeed. If any command fails, `make release-check` exits non-zero and stops at the first failure.

To discover available release/CI helpers:

```bash
make help
```

## Release policy: local-first + tag policy

Use the same branch for local experimentation as development, and keep iteration tag-free.

- Local/experimental work:
  - Always use local checks (`make ci-local`, `mix test`, etc.).
  - Keep work on the branch only.
  - Do not run `mix hex.publish`.
  - Do not push tags.
  - Normal local/experimental work expects `no tag push`.

- Release candidate path:
  - Prepare the version and changelog for release intent:
    - keep exploratory notes in `### Non-released`
    - keep release-intent content in `### Release-ready`
  - Run `make release-check`.
  - Keep iterative fixes local until `make release-check` is fully green.

- External publish/release trigger:
  - Only after the above checks pass and a maintainer explicitly approves a release, run `mix hex.publish`.
  - After publish is complete, create and push the annotated `vX.Y.Z` tag to mark the released version.
  - Tag pushes are release-only and should not be used to validate local experiments.

## Development Checks

Use the canonical plan in `scripts/ci_plan.md` for all local and CI checks.

```bash
mix ci
```

For iterative local work, run only the cheapest parity slot:

```bash
./scripts/ci_local.sh --matrix 1.15
```

For full local parity with CI, run both slots:

```bash
./scripts/ci_local.sh --matrix 1.15,1.19
```

Need a quick preview of what will run?

```bash
./scripts/ci_local.sh --dry-run --matrix 1.15,1.19
```

Matrix behavior:

- `1.15` (`1.15.8` / `26.2`) -> `deps`, `compile`, `test`
- `1.19` (`1.19.5` / `28.0`) -> `deps`, `format`, `compile`, `test`

Format is intentionally single-slot (`1.19`) to keep iterative runs faster.

You can also run via make:

```bash
make ci-local         # cheapest matrix slot
make ci-local-full    # full matrix parity
```

## Benchmark Harness

Canonical benchmark run/read/compare documentation lives in
[`docs/perf.md`](./docs/perf.md). Use that runbook for reproducibility notes,
machine caveats, warm-up guidance, and baseline/last-run reporting formats.

Run benchmarks for deterministic validate/render workloads with no manual setup:

```bash
make benchmark
```

That command uses `scripts/benchmark.sh`, which runs:

- local default output (`text`) for developer-facing visibility
- JSON output in CI (`CI=true`)

You can also call the task directly:

```bash
mix json_liveview_render.bench

# common options
mix json_liveview_render.bench --iterations 500 --suites validate,render --seed 20260301
mix json_liveview_render.bench --format json --node-count 240 --depth 7 --branching-factor 3
mix json_liveview_render.bench --matrix --iterations 120 --seed 20260301
```

Current report output includes:

- benchmark configuration (iterations, suites, seed, node_count, depth, branching_factor)
- matrix case name and node graph shape (when `--matrix` is enabled)
- project/runtime metadata (Elixir, OTP, OS, scheduler/slice counts)
- timing and throughput metrics per suite (min/max/mean/p50/p95/p99 + ops/sec)
- memory statistics per suite for matrix runs (total/mean/min/max/p50/p95)

### Validate/2 baseline (reproducible)

The following baselines use deterministic validate inputs from:

- seed `20260301`
- iterations `30`
- command:

```bash
mix json_liveview_render.bench --matrix --suites validate --seed 20260301 --iterations 30 --format json
```

Captured baseline snapshot:

```json
{
  "matrix": true,
  "cases": [
    {
      "case_name": "validate_small_depth_4_width_2_nodes_15",
      "node_count": 15,
      "p50_microseconds": 17,
      "p95_microseconds": 61,
      "memory_p50_bytes": 1328,
      "memory_p95_bytes": 99320,
      "iterations": 30
    },
    {
      "case_name": "validate_typical_depth_5_width_4_nodes_341",
      "node_count": 341,
      "p50_microseconds": 295,
      "p95_microseconds": 368,
      "memory_p50_bytes": 0,
      "memory_p95_bytes": 0,
      "iterations": 30
    },
    {
      "case_name": "validate_pathological_depth_6_width_4_nodes_1024",
      "node_count": 1024,
      "p50_microseconds": 803,
      "p95_microseconds": 859,
      "memory_p50_bytes": 0,
      "memory_p95_bytes": 0,
      "iterations": 30
    }
  ]
}
```

### Regression guardrail contract

Threshold definitions are versioned in [`benchmarks/thresholds.json`](./benchmarks/thresholds.json).

- `validate` and `render` each define:
  - enforced metric (`p95_microseconds`)
  - max allowed regression percent
  - per-case baseline values (matrix case names)
- Guardrail runs by default for both single and matrix benchmark commands.
- Default enforcement mode is `report_only` (local runs never fail automatically).
- Optional hard-fail mode:
  - CLI: `--guardrail-fail`
  - env: `BENCH_GUARDRAIL_FAIL=true`

Examples:

```bash
# report-only (default)
mix json_liveview_render.bench --matrix --seed 20260301 --iterations 30 --format json

# fail process if any threshold is exceeded
mix json_liveview_render.bench --matrix --seed 20260301 --iterations 30 --format json --guardrail-fail
```

Failure handling rules:

1. If `guardrail.status=pass`, baseline contract is satisfied.
2. If `guardrail.status=fail` and `mode=report_only`, treat as a local warning:
   - capture output,
   - rerun the same command once to rule out transient noise,
   - open/update perf follow-up if still failing.
3. If `guardrail.status=fail` and `mode=fail_on_regression`, treat as blocking:
   - do not merge/release until either:
     - performance regression is fixed, or
     - thresholds are intentionally updated with reviewer approval.

Threshold update checklist (required in PR description):

1. Include exact repro command (`seed`, `iterations`, suites, and format).
2. Include before/after guardrail output (failed old baseline, passing new baseline).
3. Explain root cause (`expected perf shift` vs `new workload shape`).
4. Confirm change scope is limited to `benchmarks/thresholds.json` (or justify extra files).
5. Link reviewer acknowledgement for baseline reset.

## Learnings

- See [LEARNINGS.md](./LEARNINGS.md) for implementation learnings and follow-up risks.

## Debugging Specs

Use `JsonLiveviewRender.Debug.inspect_spec/3` to validate and inspect topology details for a spec:

```elixir
{:ok, report} = JsonLiveviewRender.Debug.inspect_spec(spec, MyApp.UICatalog)
```

## License

MIT
