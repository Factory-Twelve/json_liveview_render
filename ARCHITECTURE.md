# Architecture

## Purpose

`json_liveview_render` is the core generative UI library for Phoenix LiveView.
It validates a flat, catalog-driven UI spec and renders that spec server-side
through a registry-backed component system.

## Canonical Spec Contract

All external UI inputs normalize into one canonical internal document shape:

```json
{
  "root": "page",
  "elements": {
    "page": {
      "type": "column",
      "props": {
        "gap": "md"
      },
      "children": ["metric_revenue"]
    },
    "metric_revenue": {
      "type": "metric",
      "props": {
        "label": "Revenue",
        "value": "$42k"
      },
      "children": []
    }
  }
}
```

This `root + elements` document is the only canonical AST/wire contract inside
the library. JSON, YAML, stream adapters, and future patch formats must target
this shape instead of inventing alternate internal models.

Related contract docs:

- `docs/wire-formats.md`
- `docs/patch-semantics.md`
- `docs/examples/canonical-spec.md`

## Top-Level Semantics

- `root` is the string id of the element rendered first in a complete document.
- `elements` is a flat map keyed by element id.
- A complete document requires `root` to exist and reference an entry in
  `elements`.
- Partial accumulation may temporarily omit `root` or reference child ids that
  have not arrived yet, but only in explicit partial-validation workflows.
- The canonical normalized output only contains `root` and `elements`. Extra
  top-level ingress keys are non-operative in v1 and must not carry behavior.

## Id Rules

- Canonical ids are strings.
- Ids are document-wide handles used by `root`, `children`, and any patch path.
- Ids should be stable across updates for the same logical node. Reordering
  siblings or editing props must not force unrelated ids to change.
- Producers should emit string ids up front. Non-string ids may be stringified
  during normalization, which is tolerated but not a canonical authoring shape.
- Producers should avoid `/` and `~` in ids unless necessary, because JSON Patch
  paths must escape them.

## Element Semantics

Each canonical element is a map with exactly three operative fields:

- `type`: string component type resolved through the catalog.
- `props`: map with string keys and JSON-like values.
- `children`: ordered list of child element ids.

Canonical element shape requires `props` and `children` to be present.

Ingress/normalization notes:

- Canonical producers should emit `props` as a map and `children` as a list,
  even when they are empty.
- Some non-canonical ingress paths may fill default `props` or `children`
  values before a document reaches canonical form, but the current string-keyed
  validator path expects those keys to already be present.
- Atom keys in ids or props may be stringified during normalization.
- Unknown element-level fields are non-operative in v1 and are not part of the
  canonical contract.

## Tree Semantics

- `root` plus `children` edges define one intended UI tree over the flat
  `elements` map.
- Child order is render order.
- In a complete document, every child id must resolve to an element.
- Canonical producers should treat duplicate child references, multiple parents
  for the same non-root node, and unreachable elements as authoring mistakes.
- Current runtime paths do not reject every tree-shape mistake yet. This
  document defines the contract that future validation and patching work should
  preserve.

## Partial Accumulation

`JsonLiveviewRender.Spec.validate_partial/3` is the current explicit seam for
incomplete state.

Partial mode allows only these temporary gaps:

- missing `root`
- `root` pointing at an element id not materialized yet
- child ids pointing at elements not materialized yet

Partial mode does not create a second AST. The in-flight state is still the
same canonical `root + elements` document, just validated with relaxed
reference checks until finalization.

## V1 Non-Goals And Reserved Fields

These semantics are explicitly out of scope for the canonical v1 contract:

- event-handler execution or action DSLs
- expression/runtime evaluation fields
- provider-specific transport or stream payloads
- alternate tree encodings outside `root + elements`
- unified diff semantics

Reserved future fields, if introduced later, are non-operative until they are
explicitly documented. No wire format may rely on undocumented extra top-level
or element-level keys in v1.

## Main Modules

- `JsonLiveviewRender.Catalog`
  Component definitions and catalog primitives.
- `JsonLiveviewRender.Spec`
  Spec normalization, validation, and error handling.
- `JsonLiveviewRender.Schema`
  JSON Schema and prompt-builder support.
- `JsonLiveviewRender.Wire.*`
  Canonical wire-format helpers such as patch application over the same
  `root + elements` contract.
- `JsonLiveviewRender.Registry`
  Mapping from catalog types to render functions.
- `JsonLiveviewRender.Renderer`
  Server-side render pipeline.
- `JsonLiveviewRender.Permissions`, `Authorizer`, `Bindings`
  Runtime safety and binding resolution.
- `JsonLiveviewRender.Stream`
  Incremental assembly/finalization over the same canonical spec.
- `JsonLiveviewRender.Debug`, `DevTools`
  Debug-oriented helpers.
- `JsonLiveviewRender.Blocks.*`
  Experimental reference block bundles; non-core companion surfaces.
- `lib/mix/tasks/`
  Library-specific tooling and bootstrapping tasks.

## Allowed Dependency Direction

- Catalog definitions feed spec and schema validation.
- Spec validation must complete before rendering.
- Registry and renderer depend on catalog/spec contracts.
- Bindings and permissions participate at render time, not as alternate sources
  of schema truth.
- Stream assembly feeds the same canonical spec contract; it does not define a
  parallel renderer format.
- Wire helpers normalize or mutate external payloads, then feed the same spec
  validation contract; they do not create alternate renderer models.
- Mix tasks should wrap public library APIs instead of reimplementing core
  behavior.

## Where New Features Belong

- New catalog DSL behavior: `Catalog`
- Validation behavior or error reporting: `Spec`
- External wire-format normalization or patch semantics: `Wire`
- JSON Schema or prompt generation: `Schema`
- Render-time composition: `Registry`, `Renderer`, `Bindings`, `Permissions`
- Streaming accumulation/finalization: `Stream`
- Experimental reference block bundles: `JsonLiveviewRender.Blocks.*`
- CLI/bootstrap tooling: `lib/mix/tasks/`

## Invariants

- The Catalog -> Spec -> Render pattern remains the core mental model.
- Canonical specs stay flat, typed, and JSON-like even when ingress syntax is
  YAML.
- Complete documents validate before render.
- Core library modules remain app-agnostic.
- Release-family scope locks in the README and changelog are real constraints,
  not suggestions.

## Common Mistakes To Avoid

- Do not add app-specific UI assumptions to the core library.
- Do not treat `JsonLiveviewRender.Blocks.*` companion surfaces as stable core API.
- Do not bypass validation and render arbitrary JSON directly.
- Do not mix provider-specific transport adapters into the core package.
- Do not introduce expression-runtime complexity without an explicit product
  decision.
- Do not add new wire formats that target anything other than canonical
  `root + elements`.
