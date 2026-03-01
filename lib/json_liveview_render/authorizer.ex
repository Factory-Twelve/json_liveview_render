defmodule JsonLiveviewRender.Authorizer do
  @moduledoc "Behavior for app-provided authorization used during rendering."

  @doc "Returns `true` if `current_user` satisfies the `required_role` for a component."
  @callback allowed?(current_user :: term(), required_role :: term()) :: boolean()
end

defmodule JsonLiveviewRender.Authorizer.AllowAll do
  @moduledoc "Default allow-all authorizer for development and permissive rendering."
  @behaviour JsonLiveviewRender.Authorizer

  @impl true
  def allowed?(_current_user, _required_role), do: true
end
