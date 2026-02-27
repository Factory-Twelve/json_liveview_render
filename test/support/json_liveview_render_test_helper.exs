defmodule JsonLiveviewRender.Test do
  @moduledoc "Test helpers for JsonLiveviewRender specs and renderer assertions."

  import ExUnit.Assertions
  require Phoenix.LiveViewTest

  @spec assert_valid_spec(map() | String.t(), module()) :: map()
  def assert_valid_spec(spec, catalog) do
    case JsonLiveviewRender.Spec.validate(spec, catalog) do
      {:ok, validated} ->
        validated

      {:error, reasons} ->
        flunk("expected spec to be valid, got errors: #{inspect(reasons)}")
    end
  end

  @spec render_spec(map(), module(), keyword()) :: String.t()
  def render_spec(spec, catalog, opts \\ []) do
    registry = Keyword.fetch!(opts, :registry)
    current_user = Keyword.get(opts, :current_user, %{role: :member})
    authorizer = Keyword.get(opts, :authorizer, JsonLiveviewRender.Authorizer.AllowAll)
    bindings = Keyword.get(opts, :bindings, %{})
    strict = Keyword.get(opts, :strict, true)
    check_binding_types = Keyword.get(opts, :check_binding_types, false)
    allow_partial = Keyword.get(opts, :allow_partial, false)
    dev_tools = Keyword.get(opts, :dev_tools, false)
    dev_tools_open = Keyword.get(opts, :dev_tools_open, false)
    dev_tools_enabled = Keyword.get(opts, :dev_tools_enabled, nil)
    dev_tools_force_disable = Keyword.get(opts, :dev_tools_force_disable, false)

    Phoenix.LiveViewTest.render_component(&JsonLiveviewRender.Renderer.render/1,
      spec: spec,
      catalog: catalog,
      registry: registry,
      current_user: current_user,
      authorizer: authorizer,
      bindings: bindings,
      strict: strict,
      check_binding_types: check_binding_types,
      allow_partial: allow_partial,
      dev_tools: dev_tools,
      dev_tools_open: dev_tools_open,
      dev_tools_enabled: dev_tools_enabled,
      dev_tools_force_disable: dev_tools_force_disable
    )
  end

  @spec render_spec_in_production_env(map(), module(), keyword()) :: String.t()
  def render_spec_in_production_env(spec, catalog, opts \\ []) do
    render_spec(spec, catalog, Keyword.put_new(opts, :dev_tools_enabled, false))
  end

  @spec assert_no_dev_tools_output(String.t()) :: :ok
  def assert_no_dev_tools_output(html) do
    refute String.contains?(html, "data-json-liveview-render-devtools")
    refute String.contains?(html, "Input Spec")
    refute String.contains?(html, "Rendered Spec")
    refute String.contains?(html, "Input Errors")
    refute String.contains?(html, "Rendered Errors")
    :ok
  end
end
