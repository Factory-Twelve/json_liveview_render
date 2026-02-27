defmodule JsonLiveviewRender.Stream.Adapter do
  @moduledoc """
  Streaming adapter behavior for provider events.

  API scope:

  - Stability: experimental / deferred
  - Companion package surface for production transport adapters

  Behavior for converting provider-specific payloads into stream events.

  Adapters are intentionally thin translation layers that output one of:
  - `{:root, id}`
  - `{:element, id, element}`
  - `{:finalize}`
  """

  @type normalized :: {:ok, JsonLiveviewRender.Stream.event()} | :ignore | {:error, term()}

  @callback normalize_event(map()) :: normalized()
end
