defmodule JsonLiveviewRender.Spec.Normalizer do
  @moduledoc "Shared normalization helpers used by Spec validation and Stream ingestion."

  @doc "Normalizes an element map to string keys for `type`, `props`, and `children`."
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

  @doc "Normalizes an element map for canonical paths and rejects non-scalar ids/prop keys."
  @spec normalize_element_canonical(map()) ::
          {:ok, map()} | {:error, {:invalid_canonical_value, atom(), term()}}
  def normalize_element_canonical(element) when is_map(element) do
    type = Map.get(element, "type") || Map.get(element, :type)
    props = Map.get(element, "props", Map.get(element, :props, %{}))
    children = Map.get(element, "children", Map.get(element, :children, []))

    with {:ok, normalized_props} <- normalize_props_canonical(props),
         {:ok, normalized_children} <- normalize_children_canonical(children) do
      {:ok,
       %{
         "type" => if(is_atom(type), do: Atom.to_string(type), else: type),
         "props" => normalized_props,
         "children" => normalized_children
       }}
    end
  end

  def normalize_element_canonical(element), do: {:ok, element}

  @doc "Converts prop keys to strings."
  @spec normalize_props(map()) :: map()
  def normalize_props(props) when is_map(props) do
    Map.new(props, fn {k, v} -> {safe_to_string(k), v} end)
  end

  def normalize_props(props), do: props

  @doc "Converts child IDs to strings."
  @spec normalize_children(list()) :: list()
  def normalize_children(children) when is_list(children) do
    Enum.map(children, &safe_to_string/1)
  end

  def normalize_children(children), do: children

  @doc false
  @spec safe_to_string(term()) :: String.t()
  def safe_to_string(value) do
    to_string(value)
  rescue
    _ -> inspect(value)
  end

  @doc false
  @spec canonical_string(term(), atom()) ::
          {:ok, String.t()} | {:error, {:invalid_canonical_value, atom(), term()}}
  def canonical_string(value, _context)
      when is_binary(value) or is_atom(value) or is_boolean(value) or is_number(value) do
    {:ok, to_string(value)}
  end

  def canonical_string(value, context), do: {:error, {:invalid_canonical_value, context, value}}

  defp normalize_props_canonical(props) when is_map(props) do
    Enum.reduce_while(props, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case canonical_string(key, :prop_key) do
        {:ok, normalized_key} -> {:cont, {:ok, Map.put(acc, normalized_key, value)}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp normalize_props_canonical(props), do: {:ok, props}

  defp normalize_children_canonical(children) when is_list(children) do
    Enum.reduce_while(children, {:ok, []}, fn child_id, {:ok, acc} ->
      case canonical_string(child_id, :child_id) do
        {:ok, normalized_child_id} -> {:cont, {:ok, [normalized_child_id | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed_children} -> {:ok, Enum.reverse(reversed_children)}
      {:error, _} = error -> error
    end
  end

  defp normalize_children_canonical(children), do: {:ok, children}
end
