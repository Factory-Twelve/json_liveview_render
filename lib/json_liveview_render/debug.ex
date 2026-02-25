defmodule JsonLiveviewRender.Debug do
  @moduledoc "Debug helpers for inspecting JsonLiveviewRender specs during development."

  alias JsonLiveviewRender.Spec

  @spec inspect_spec(map() | String.t(), module(), keyword()) ::
          {:ok, map()} | {:error, [term()]}
  def inspect_spec(spec, catalog, opts \\ []) do
    strict? = Keyword.get(opts, :strict, true)

    case Spec.validate(spec, catalog, strict: strict?) do
      {:ok, %{"root" => root, "elements" => elements} = validated} ->
        reachable = reachable_ids(root, elements)
        types = Enum.frequencies_by(elements, fn {_id, element} -> Map.get(element, "type") end)

        report = %{
          root: root,
          element_count: map_size(elements),
          reachable_count: MapSet.size(reachable),
          orphan_ids:
            elements |> Map.keys() |> Enum.reject(&MapSet.member?(reachable, &1)) |> Enum.sort(),
          component_counts: types,
          max_depth: max_depth(root, elements),
          leaf_ids: leaf_ids(elements),
          spec: validated
        }

        {:ok, report}

      {:error, reasons} ->
        {:error, reasons}
    end
  end

  defp reachable_ids(root, elements), do: dfs(root, elements, MapSet.new())

  defp dfs(nil, _elements, visited), do: visited

  defp dfs(id, elements, visited) do
    cond do
      MapSet.member?(visited, id) ->
        visited

      true ->
        children = elements |> Map.get(id, %{}) |> Map.get("children", [])
        visited = MapSet.put(visited, id)
        Enum.reduce(children, visited, &dfs(&1, elements, &2))
    end
  end

  defp max_depth(root, elements), do: depth(root, elements, 0, MapSet.new())

  defp depth(nil, _elements, current, _seen), do: current

  defp depth(id, elements, current, seen) do
    cond do
      MapSet.member?(seen, id) ->
        current

      true ->
        children = elements |> Map.get(id, %{}) |> Map.get("children", [])
        seen = MapSet.put(seen, id)

        case children do
          [] ->
            current

          _ ->
            children
            |> Enum.map(&depth(&1, elements, current + 1, seen))
            |> Enum.max(fn -> current end)
        end
    end
  end

  defp leaf_ids(elements) do
    elements
    |> Enum.filter(fn {_id, element} -> Map.get(element, "children", []) == [] end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end
end
