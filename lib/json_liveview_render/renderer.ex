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
  `allow_partial`, `error_boundary`, `dev_tools`, `dev_tools_open`,
  `dev_tools_enabled`, `dev_tools_force_disable`.
  """

  use Phoenix.Component

  require Logger

  alias JsonLiveviewRender.Bindings
  alias JsonLiveviewRender.Catalog.ComponentDef
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
  attr(:error_boundary, :boolean, default: false)

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

    type_context =
      build_type_context(
        filtered_spec,
        assigns.catalog,
        assigns.registry,
        assigns.error_boundary
      )

    assigns =
      assigns
      |> assign(:_genui_spec, filtered_spec)
      |> assign(:_genui_root, root)
      |> assign(:_genui_type_context, type_context)

    ~H"""
    <%= if @_genui_root && Map.has_key?(@_genui_spec["elements"], @_genui_root) do %>
      <%= render_element(@_genui_root, @_genui_spec, @_genui_type_context, @bindings, @check_binding_types, @error_boundary) %>
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

  defp build_type_context(
         %{"root" => root, "elements" => elements},
         catalog,
         registry,
         error_boundary
       ) do
    {_visited, _types, context} =
      collect_type_context(
        root,
        elements,
        catalog,
        registry,
        error_boundary,
        MapSet.new(),
        MapSet.new(),
        %{}
      )

    context
  end

  defp collect_type_context(
         nil,
         _elements,
         _catalog,
         _registry,
         _error_boundary,
         visited_ids,
         seen_types,
         context
       ),
       do: {visited_ids, seen_types, context}

  defp collect_type_context(
         id,
         elements,
         catalog,
         registry,
         error_boundary,
         visited_ids,
         seen_types,
         context
       ) do
    cond do
      MapSet.member?(visited_ids, id) ->
        {visited_ids, seen_types, context}

      true ->
        case Map.fetch(elements, id) do
          {:ok, %{"type" => type} = element} ->
            visited_ids = MapSet.put(visited_ids, id)

            {seen_types, context} =
              put_type_context(type, catalog, registry, error_boundary, seen_types, context)

            Enum.reduce(
              Map.get(element, "children", []),
              {visited_ids, seen_types, context},
              fn child_id, {acc_visited, acc_seen_types, acc_context} ->
                collect_type_context(
                  child_id,
                  elements,
                  catalog,
                  registry,
                  error_boundary,
                  acc_visited,
                  acc_seen_types,
                  acc_context
                )
              end
            )

          _ ->
            {MapSet.put(visited_ids, id), seen_types, context}
        end
    end
  end

  defp put_type_context(type, catalog, registry, error_boundary, seen_types, context) do
    if MapSet.member?(seen_types, type) do
      {seen_types, context}
    else
      component = catalog.component(type)

      metadata = %{
        assign_key_map: ComponentDef.assign_key_map(component),
        callback: fetch_callback(registry, type, error_boundary),
        component: component,
        defaults: ComponentDef.defaults(component)
      }

      {MapSet.put(seen_types, type), Map.put(context, type, metadata)}
    end
  end

  defp fetch_callback(registry, type, false), do: Registry.fetch!(registry, type)

  defp fetch_callback(registry, type, true) do
    Registry.fetch!(registry, type)
  rescue
    exception -> {:error, exception}
  end

  defp render_element(id, spec, type_context, bindings, check_binding_types, error_boundary) do
    element = get_in(spec, ["elements", id])

    case element do
      nil ->
        nil

      %{"type" => type} = element ->
        if error_boundary do
          try do
            do_render_element(
              type,
              element,
              spec,
              type_context,
              bindings,
              check_binding_types,
              error_boundary
            )
          rescue
            e ->
              Logger.warning(
                "[JsonLiveviewRender.Renderer] error boundary caught error rendering element #{inspect(id)}: #{Exception.message(e)}"
              )

              nil
          end
        else
          do_render_element(
            type,
            element,
            spec,
            type_context,
            bindings,
            check_binding_types,
            error_boundary
          )
        end
    end
  end

  defp do_render_element(
         type,
         element,
         spec,
         type_context,
         bindings,
         check_binding_types,
         error_boundary
       ) do
    %{
      assign_key_map: assign_key_map,
      callback: callback,
      component: component,
      defaults: defaults
    } =
      Map.fetch!(type_context, type)

    callback = resolve_callback!(callback)
    raw_props = Map.get(element, "props", %{})
    props_with_defaults = apply_defaults(raw_props, defaults)

    resolved_props =
      Bindings.resolve_props(props_with_defaults, bindings,
        literal_props: raw_props,
        prop_defs: component.props,
        check_types: check_binding_types
      )

    children =
      element
      |> Map.get("children", [])
      |> Enum.map(
        &render_element(
          &1,
          spec,
          type_context,
          bindings,
          check_binding_types,
          error_boundary
        )
      )

    assigns = to_component_assigns(assign_key_map, resolved_props, children)

    callback.(assigns)
  end

  defp resolve_callback!({:error, exception}), do: raise(exception)
  defp resolve_callback!(callback), do: callback

  defp apply_defaults(props, defaults) when defaults == %{}, do: props
  defp apply_defaults(props, defaults), do: Map.merge(defaults, props)

  defp to_component_assigns(assign_key_map, resolved_props, children) do
    prop_assigns =
      Enum.reduce(resolved_props, %{}, fn {key, value}, acc ->
        case Map.fetch(assign_key_map, key) do
          {:ok, assign_key} -> Map.put(acc, assign_key, value)
          :error -> acc
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
