# Architecture

## Purpose

`json_liveview_render` is the core generative UI library for Phoenix LiveView. It validates typed
catalog-driven JSON specs and renders them server-side through a registry-backed component system.

## Main Modules

- `JsonLiveviewRender.Catalog`
  Component definitions and catalog primitives.
- `JsonLiveviewRender.Spec`
  Spec validation and error handling.
- `JsonLiveviewRender.Schema`
  JSON Schema and prompt-builder support.
- `JsonLiveviewRender.Registry`
  Mapping from catalog types to render functions.
- `JsonLiveviewRender.Renderer`
  Server-side render pipeline.
- `JsonLiveviewRender.Permissions`, `Authorizer`, `Bindings`
  Runtime safety and binding resolution.
- `JsonLiveviewRender.Stream`
  Streaming/partial rendering surface.
- `JsonLiveviewRender.Debug`, `DevTools`
  Debug-oriented helpers.
- `lib/mix/tasks/`
  Library-specific tooling and bootstrapping tasks.

## Allowed Dependency Direction

- Catalog definitions feed spec and schema validation.
- Spec validation must complete before rendering.
- Registry and renderer depend on catalog/spec contracts.
- Bindings and permissions participate at render time, not as alternate sources of schema truth.
- Mix tasks should wrap public library APIs instead of reimplementing core behavior.

## Where New Features Belong

- New catalog DSL behavior: `Catalog`
- Validation behavior or error reporting: `Spec`
- JSON Schema or prompt generation: `Schema`
- Render-time composition: `Registry`, `Renderer`, `Bindings`, `Permissions`
- Streaming behavior: `Stream`
- CLI/bootstrap tooling: `lib/mix/tasks/`

## Invariants

- The Catalog -> Spec -> Render pattern remains the core mental model.
- Specs should stay flat, typed, and validated before render.
- Core library modules should remain app-agnostic.
- Release-family scope locks in the README and changelog are real constraints, not suggestions.

## Common Mistakes To Avoid

- Do not add app-specific UI assumptions to the core library.
- Do not bypass validation and render arbitrary JSON directly.
- Do not mix transport-specific adapters into the core package.
- Do not introduce expression-runtime complexity without an explicit product decision.
