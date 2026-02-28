defmodule JsonLiveviewRender.Renderer do
  @moduledoc """
  Stable v0.2 core rendering component for JsonLiveviewRender specs.

  API scope:

  - Stability: v0.2 stable contract (included in the v0.3 lock)
  - Required assigns:
    `spec`, `catalog`, `registry`, `current_user`.
  - v0.3-only extension: partial-render mode via `allow_partial`.

  Optional assigns:
  `bindings`, `authorizer`, `strict`, `check_binding_types`,
  `allow_partial`, `dev_tools`, `dev_tools_open`,
  `dev_tools_enabled`, `dev_tools_force_disable`.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Bindings
  alias JsonLiveviewRender.Permissions
  alias JsonLiveviewRender.Registry
  alias JsonLiveviewRender.Spec

  attr(:spec, :map, required: true)
  attr(:catalog, :any, required: true)
  attr(:registry, :any, required: true)
  attr(:bindings, :map, default: %{})
  attr(:current_user, :any, required: true)
  attr(:authorizer, :any, default: JsonLiveviewRender.Authorizer.AllowAll)
  attr(:strict, :boolean, default: true)
  attr(:check_binding_types, :boolean, default: false)
  attr(:allow_partial, :boolean, default: false)
  attr(:dev_tools, :boolean, default: false)
  attr(:dev_tools_open, :boolean, default: false)
  attr(:dev_tools_enabled, :any, default: nil)
  attr(:dev_tools_force_disable, :boolean, default: false)

  def render(assigns) do
    validator = spec_validator(assigns.allow_partial)

    validated_spec =
      case validator.(assigns.spec, assigns.catalog, strict: assigns.strict) do
        {:ok, spec} ->
          spec

        {:error, reasons} ->
          raise ArgumentError, "invalid JsonLiveviewRender spec: #{inspect(reasons)}"
      end

    filtered_spec =
      Permissions.filter(
        validated_spec,
        assigns.current_user,
        assigns.catalog,
        assigns.authorizer
      )

    root = filtered_spec["root"]

    assigns =
      assigns
      |> assign(:_genui_spec, filtered_spec)
      |> assign(:_genui_root, root)

    ~H"""
    <%= if @_genui_root && Map.has_key?(@_genui_spec["elements"], @_genui_root) do %>
      <%= render_element(@_genui_root, @_genui_spec, @catalog, @registry, @bindings, @check_binding_types) %>
    <% end %>

    <%= if dev_tools_enabled?(@dev_tools, @dev_tools_enabled, @dev_tools_force_disable) do %>
      <JsonLiveviewRender.DevTools.render
        input_spec={@spec}
        render_spec={@_genui_spec}
        catalog={@catalog}
        strict={@strict}
        allow_partial={@allow_partial}
        open={@dev_tools_open}
      />
    <% end %>
    """
  end

  defp spec_validator(true), do: &Spec.validate_partial/3
  defp spec_validator(_), do: &Spec.validate/3

  defp dev_tools_enabled?(requested?, config_enabled?, force_disable?) do
    requested? &&
      !force_disable? &&
      dev_tools_configuration_enabled?(config_enabled?) &&
      Code.ensure_loaded?(JsonLiveviewRender.DevTools) &&
      function_exported?(JsonLiveviewRender.DevTools, :render, 1)
  end

  defp dev_tools_configuration_enabled?(nil) do
    normalize_dev_tools_enabled(
      Application.get_env(:json_liveview_render, :dev_tools_enabled, false)
    )
  end

  defp dev_tools_configuration_enabled?(value), do: normalize_dev_tools_enabled(value)

  defp normalize_dev_tools_enabled(true), do: true
  defp normalize_dev_tools_enabled(_), do: false

  defp render_element(id, spec, catalog, registry, bindings, check_binding_types) do
    element = get_in(spec, ["elements", id])

    case element do
      nil ->
        nil

      %{"type" => type} = element ->
        component = catalog.component(type)
        callback = Registry.fetch!(registry, type)

        raw_props = Map.get(element, "props", %{})
        props_with_defaults = apply_defaults(raw_props, component.props)

        resolved_props =
          Bindings.resolve_props(props_with_defaults, bindings,
            prop_defs: component.props,
            check_types: check_binding_types
          )

        children =
          element
          |> Map.get("children", [])
          |> Enum.map(&render_element(&1, spec, catalog, registry, bindings, check_binding_types))

        assigns = to_component_assigns(component.props, resolved_props, children)

        callback.(assigns)
    end
  end

  defp apply_defaults(props, prop_defs) do
    Enum.reduce(prop_defs, props, fn {prop_name, prop_def}, acc ->
      key = Atom.to_string(prop_name)

      if Map.has_key?(acc, key) or is_nil(prop_def.default) do
        acc
      else
        Map.put(acc, key, prop_def.default)
      end
    end)
  end

  defp to_component_assigns(prop_defs, resolved_props, children) do
    allowed_keys =
      prop_defs
      |> Map.keys()
      |> Enum.map(&Atom.to_string/1)
      |> Enum.flat_map(fn key ->
        if String.ends_with?(key, "_binding") do
          [key, String.replace_suffix(key, "_binding", "")]
        else
          [key]
        end
      end)
      |> MapSet.new()

    prop_assigns =
      Enum.reduce(resolved_props, %{}, fn {key, value}, acc ->
        if MapSet.member?(allowed_keys, key) do
          Map.put(acc, String.to_atom(key), value)
        else
          acc
        end
      end)

    # Canonical child slot projection: :children is the primary slot key.
    # Always provide a list structure - empty list for missing slots instead of nil.
    # This ensures deterministic slot payload shape for component rendering.
    normalized_children = normalize_child_slots(children)

    Map.put(prop_assigns, :children, normalized_children)
  end

  defp normalize_child_slots(children) when is_list(children), do: children
  defp normalize_child_slots(nil), do: []
  defp normalize_child_slots(_), do: []
end
