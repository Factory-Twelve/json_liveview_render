defmodule JsonLiveviewRender.Spec.AutoFix do
  @moduledoc """
  Auto-fixes common AI mistakes in generated specs.

  Applies safe, deterministic transformations:
  - Prop type coercion (string → integer/float/boolean)
  - Children normalization (single string → list)
  - Orphan element detection (warning for unreachable elements)
  """

  alias JsonLiveviewRender.Catalog.ComponentDef
  alias JsonLiveviewRender.Catalog.PropDef
  alias JsonLiveviewRender.Spec.Normalizer

  @type fix :: String.t()

  @doc """
  Attempts to auto-fix a spec against a catalog.

  Returns `{:ok, fixed_spec, fixes}` where `fixes` is a list of human-readable
  descriptions of each applied fix. Returns `{:error, reason}` if the spec
  is not structurally valid enough to attempt fixes.
  """
  @spec auto_fix(map(), module()) :: {:ok, map(), [fix()]} | {:error, term()}
  def auto_fix(spec, catalog) when is_map(spec) do
    root = Map.get(spec, "root") || Map.get(spec, :root)
    elements = Map.get(spec, "elements") || Map.get(spec, :elements)

    cond do
      is_nil(elements) or not is_map(elements) ->
        {:error, :elements_missing}

      true ->
        root = if is_atom(root) and not is_nil(root), do: Atom.to_string(root), else: root

        elements =
          Map.new(elements, fn {id, el} ->
            {to_string(id), normalize_element_for_fix(el)}
          end)

        {fixed_elements, fixes} = fix_elements(elements, catalog)
        orphan_warnings = detect_orphans(root, fixed_elements)

        fixed_spec = %{"root" => root, "elements" => fixed_elements}
        {:ok, fixed_spec, fixes ++ orphan_warnings}
    end
  end

  defp normalize_element_for_fix(element) when is_map(element) do
    type = Map.get(element, "type") || Map.get(element, :type)
    props = Map.get(element, "props", Map.get(element, :props, %{}))
    children = Map.get(element, "children", Map.get(element, :children, []))

    %{
      "type" => if(is_atom(type), do: Atom.to_string(type), else: type),
      "props" => Normalizer.normalize_props(props),
      "children" => children
    }
  end

  defp normalize_element_for_fix(element), do: element

  defp fix_elements(elements, catalog) do
    Enum.reduce(elements, {%{}, []}, fn {id, element}, {acc_elements, acc_fixes} ->
      {fixed, fixes} = fix_element(id, element, catalog)
      {Map.put(acc_elements, id, fixed), acc_fixes ++ fixes}
    end)
  end

  defp fix_element(id, %{"type" => type} = element, catalog) do
    {children, children_fixes} = fix_children(id, element)
    element = Map.put(element, "children", children)

    case catalog.component(type) do
      %ComponentDef{props: prop_defs} ->
        {fixed_props, prop_fixes} = fix_props(id, Map.get(element, "props", %{}), prop_defs)
        {Map.put(element, "props", fixed_props), children_fixes ++ prop_fixes}

      nil ->
        {element, children_fixes}
    end
  end

  defp fix_element(_id, element, _catalog), do: {element, []}

  defp fix_children(id, element) do
    children = Map.get(element, "children", [])

    case children do
      c when is_binary(c) ->
        fix = ~s(element #{inspect(id)}: wrapped single child string #{inspect(c)} into list)
        {[c], [fix]}

      c when is_list(c) ->
        {Enum.map(c, &to_string/1), []}

      _ ->
        {[], []}
    end
  end

  defp fix_props(id, props, prop_defs) when is_map(props) do
    Enum.reduce(prop_defs, {props, []}, fn {prop_name, %PropDef{type: expected_type}},
                                            {acc_props, acc_fixes} ->
      key = Atom.to_string(prop_name)

      case Map.fetch(acc_props, key) do
        {:ok, value} ->
          case coerce(value, expected_type) do
            {:coerced, new_value} ->
              fix =
                ~s(element #{inspect(id)} prop #{inspect(key)}: coerced #{inspect(value)} to #{format_type(expected_type)} #{inspect(new_value)})

              {Map.put(acc_props, key, new_value), acc_fixes ++ [fix]}

            :no_change ->
              {acc_props, acc_fixes}
          end

        :error ->
          {acc_props, acc_fixes}
      end
    end)
  end

  defp fix_props(_id, props, _prop_defs), do: {props, []}

  defp coerce(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:coerced, int}
      _ -> :no_change
    end
  end

  defp coerce(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {float, ""} -> {:coerced, float}
      _ -> :no_change
    end
  end

  defp coerce(value, :boolean) when is_binary(value) do
    case String.downcase(value) do
      "true" -> {:coerced, true}
      "false" -> {:coerced, false}
      _ -> :no_change
    end
  end

  defp coerce(_value, _type), do: :no_change

  defp format_type(:integer), do: "integer"
  defp format_type(:float), do: "float"
  defp format_type(:boolean), do: "boolean"
  defp format_type(other), do: inspect(other)

  defp detect_orphans(nil, _elements), do: []

  defp detect_orphans(root, elements) do
    reachable = collect_reachable(root, elements, MapSet.new())
    all_ids = Map.keys(elements) |> MapSet.new()

    MapSet.difference(all_ids, reachable)
    |> Enum.sort()
    |> Enum.map(fn id ->
      "warning: element #{inspect(id)} is not reachable from root #{inspect(root)}"
    end)
  end

  defp collect_reachable(id, elements, visited) do
    if MapSet.member?(visited, id) or not Map.has_key?(elements, id) do
      visited
    else
      visited = MapSet.put(visited, id)
      children = elements |> Map.get(id, %{}) |> Map.get("children", [])

      Enum.reduce(children, visited, fn child_id, acc ->
        collect_reachable(to_string(child_id), elements, acc)
      end)
    end
  end
end
