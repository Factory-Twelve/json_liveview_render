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
    Map.new(props, fn {k, v} -> {safe_to_string(k), v} end)
  end

  def normalize_props(props), do: props

  @spec normalize_children(list()) :: list()
  def normalize_children(children) when is_list(children) do
    Enum.map(children, &safe_to_string/1)
  end

  def normalize_children(children), do: children

  @doc false
  def safe_to_string(value) do
    to_string(value)
  rescue
    _ -> inspect(value)
  end
end
