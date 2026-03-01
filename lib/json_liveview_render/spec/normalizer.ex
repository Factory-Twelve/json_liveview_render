defmodule JsonLiveviewRender.Spec.Normalizer do
  @moduledoc false

  @spec normalize_element(map()) :: map()
  def normalize_element(element) when is_map(element) do
    type = Map.get(element, "type") || Map.get(element, :type)
    props = Map.get(element, "props", Map.get(element, :props, %{}))
    children = Map.get(element, "children", Map.get(element, :children, []))

    %{
      "type" => if(is_atom(type), do: Atom.to_string(type), else: type),
      "props" => normalize_props(props),
      "children" => normalize_children(children)
    }
  end

  def normalize_element(element), do: element

  @spec normalize_props(map()) :: map()
  def normalize_props(props) when is_map(props) do
    Map.new(props, fn {k, v} -> {to_string(k), v} end)
  end

  def normalize_props(props), do: props

  @spec normalize_children(list()) :: list()
  def normalize_children(children) when is_list(children), do: Enum.map(children, &to_string/1)
  def normalize_children(children), do: children
end
