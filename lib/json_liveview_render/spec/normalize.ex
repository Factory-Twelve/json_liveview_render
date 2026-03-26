defmodule JsonLiveviewRender.Spec.Normalize do
  @moduledoc false

  alias JsonLiveviewRender.Spec.Normalizer

  @type normalization_result :: {:ok, map()} | {:error, [term()]}

  @doc """
  Normalizes external spec input for the existing validation entrypoints.

  This preserves the current `Spec.validate*` ingress behavior, including the
  string-key fast path for already-normalized `root + elements` maps.
  """
  @spec for_validation(map() | String.t()) :: normalization_result()
  def for_validation(spec) when is_map(spec), do: {:ok, normalize_for_validation(spec)}

  def for_validation(spec) when is_binary(spec) do
    with {:ok, decoded} <- Jason.decode(spec) do
      validation_decoded(decoded)
    else
      {:error, reason} -> {:error, [{:invalid_json, reason}]}
    end
  end

  def for_validation(_), do: {:error, [{:invalid_spec, "spec must be a map or JSON string"}]}

  @doc """
  Normalizes external spec input into one deterministic canonical `root + elements` map.
  """
  @spec canonical(map() | String.t()) :: normalization_result()
  def canonical(spec) when is_map(spec), do: normalize_canonical(spec)

  def canonical(spec) when is_binary(spec) do
    with {:ok, decoded} <- Jason.decode(spec) do
      canonical_decoded(decoded)
    else
      {:error, reason} -> {:error, [{:invalid_json, reason}]}
    end
  end

  def canonical(_), do: {:error, [{:invalid_spec, "spec must be a map or JSON string"}]}

  defp canonical_decoded(decoded) when is_map(decoded), do: normalize_canonical(decoded)

  defp canonical_decoded(_decoded),
    do: {:error, [{:invalid_spec, "spec must be a map or JSON string"}]}

  defp validation_decoded(decoded) when is_map(decoded),
    do: {:ok, normalize_for_validation(decoded)}

  defp validation_decoded(_decoded),
    do: {:error, [{:invalid_spec, "spec must be a map or JSON string"}]}

  defp normalize_for_validation(spec) do
    %{
      "root" => normalize_legacy_root(fetch_present_key(spec, :root, "root")),
      "elements" => normalize_legacy_elements(fetch_present_key(spec, :elements, "elements"))
    }
  end

  defp normalize_canonical(spec) do
    with {:ok, root} <- normalize_canonical_root(fetch_canonical_root(spec)),
         {:ok, elements} <- normalize_canonical_elements(fetch_canonical_elements(spec)) do
      {:ok, %{"root" => root, "elements" => elements}}
    end
  end

  defp fetch_canonical_root(spec), do: fetch_present_key(spec, :root, "root")
  defp fetch_canonical_elements(spec), do: fetch_present_key(spec, :elements, "elements")

  defp fetch_present_key(spec, atom_key, string_key) do
    cond do
      Map.has_key?(spec, atom_key) -> Map.get(spec, atom_key)
      Map.has_key?(spec, string_key) -> Map.get(spec, string_key)
      true -> nil
    end
  end

  defp normalize_legacy_root(nil), do: nil
  defp normalize_legacy_root(root) when is_atom(root), do: Atom.to_string(root)
  defp normalize_legacy_root(root), do: root

  defp normalize_canonical_root(nil), do: {:ok, nil}

  defp normalize_canonical_root(root) do
    case Normalizer.canonical_string(root, :root) do
      {:ok, normalized_root} -> {:ok, normalized_root}
      {:error, {:invalid_canonical_value, _, value}} -> invalid_canonical_value("root", value)
    end
  end

  defp normalize_legacy_elements(elements) when is_map(elements) do
    Map.new(elements, fn {id, element} ->
      {to_string(id), Normalizer.normalize_element(element)}
    end)
  end

  defp normalize_legacy_elements(elements), do: elements

  defp normalize_canonical_elements(elements) when is_map(elements) do
    Enum.reduce_while(elements, {:ok, %{}}, fn {id, element}, {:ok, acc} ->
      with {:ok, normalized_id} <- normalize_canonical_id(id),
           {:ok, normalized_element} <- Normalizer.normalize_element_canonical(element) do
        {:cont, {:ok, Map.put(acc, normalized_id, normalized_element)}}
      else
        {:error, {:invalid_canonical_value, :prop_key, value}} ->
          {:halt, invalid_canonical_value("prop key", value)}

        {:error, {:invalid_canonical_value, :child_id, value}} ->
          {:halt, invalid_canonical_value("child id", value)}

        {:error, {:invalid_canonical_value, :element_id, value}} ->
          {:halt, invalid_canonical_value("element id", value)}
      end
    end)
  end

  defp normalize_canonical_elements(elements), do: {:ok, elements}

  defp normalize_canonical_id(id) do
    case Normalizer.canonical_string(id, :element_id) do
      {:ok, normalized_id} -> {:ok, normalized_id}
      {:error, _} = error -> error
    end
  end

  defp invalid_canonical_value(label, value) do
    {:error,
     [
       {:invalid_spec,
        "canonical #{label}s must be strings, atoms, booleans, or numbers, got: #{inspect(value)}"}
     ]}
  end
end
