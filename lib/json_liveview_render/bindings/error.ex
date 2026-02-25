defmodule JsonLiveviewRender.Bindings.Error do
  @moduledoc "Raised for binding key/value resolution failures in `JsonLiveviewRender.Bindings`."

  defexception [:type, :key, :expected, :actual, :message]
end
