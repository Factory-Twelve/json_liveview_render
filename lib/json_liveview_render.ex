defmodule JsonLiveviewRender do
  @moduledoc """
  JsonLiveviewRender is a guardrailed generative UI toolkit for Phoenix LiveView.

  API families:

  Stable v0.2 core (contract):

  - `JsonLiveviewRender.Catalog` - catalog DSL for component contracts
  - `JsonLiveviewRender.Spec` - flat-spec validation
  - `JsonLiveviewRender.Registry` - explicit component mapping
  - `JsonLiveviewRender.Renderer` - permission-aware recursive rendering
  - `JsonLiveviewRender.Schema` - JSON Schema and prompt export
  - `JsonLiveviewRender.Debug` - spec diagnostics and topology summaries
  - `JsonLiveviewRender.Permissions` - app-provided authorization filter
  - `JsonLiveviewRender.Bindings` - runtime `_binding` prop resolution

  v0.3 candidate (frozen scope, core package):

  - `JsonLiveviewRender.Stream` - structured event-based spec accumulator
  - `JsonLiveviewRender.Stream.Adapter.*` - provider event normalization examples

  Experimental:

  - `JsonLiveviewRender.DevTools` - in-browser spec inspector for local development

  API tags:

  - In-scope for v0.3 lock: all stable v0.2 core modules and `JsonLiveviewRender.Stream` APIs
  - Experimental / deferred: `JsonLiveviewRender.Stream.Adapter.*`, `JsonLiveviewRender.DevTools`, and transport adapters
  - Cross-platform / provider adapter packages are intentionally out of this package scope
  """
end
