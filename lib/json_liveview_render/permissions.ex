defmodule JsonLiveviewRender.Permissions do
  @moduledoc """
  Permission filtering contract for `JsonLiveviewRender` specs.

  API scope:

  - Stability: v0.2 core contract
  - Included in the v0.3 package scope lock

  Delegates visibility decisions to an app-provided authorization function or callback
  and removes unauthorized elements before invoking component rendering.
  """

  alias JsonLiveviewRender.Catalog.ComponentDef

  @spec filter(map(), term(), module(), module() | (term(), atom() -> boolean())) :: map()
  def filter(%{"root" => root, "elements" => elements} = spec, current_user, catalog, authorizer)
      when is_map(elements) do
    allowed_ids =
      elements
      |> Enum.filter(fn {_id, element} ->
        allowed_element?(element, catalog, current_user, authorizer)
      end)
      |> Enum.map(fn {id, _} -> id end)
      |> MapSet.new()

    filtered_elements =
      elements
      |> Enum.filter(fn {id, _} -> MapSet.member?(allowed_ids, id) end)
      |> Enum.into(%{}, fn {id, element} ->
        children =
          Map.get(element, "children", []) |> Enum.filter(&MapSet.member?(allowed_ids, &1))

        {id, Map.put(element, "children", children)}
      end)

    spec
    |> Map.put("root", root)
    |> Map.put("elements", filtered_elements)
  end

  def filter(spec, _current_user, _catalog, _authorizer), do: spec

  defp allowed_element?(%{"type" => type}, catalog, current_user, authorizer) do
    case catalog.component(type) do
      %ComponentDef{permission: nil} ->
        true

      %ComponentDef{permission: required_role} ->
        allowed?(authorizer, current_user, required_role)

      nil ->
        false
    end
  end

  defp allowed_element?(_element, _catalog, _current_user, _authorizer), do: false

  defp allowed?(authorizer, current_user, required_role) when is_atom(authorizer) do
    authorizer
    |> apply(:allowed?, [current_user, required_role])
    |> normalize_authorizer_result!(authorizer)
  end

  defp allowed?(authorizer, current_user, required_role) when is_function(authorizer, 2) do
    authorizer
    |> Kernel.apply([current_user, required_role])
    |> normalize_authorizer_result!(authorizer)
  end

  defp normalize_authorizer_result!(result, _authorizer) when is_boolean(result), do: result

  defp normalize_authorizer_result!(result, authorizer) do
    raise ArgumentError,
          "authorizer #{inspect(authorizer)} must return boolean from allowed?/2, got: #{inspect(result)}"
  end
end
