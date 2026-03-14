defmodule JsonLiveviewRender.Wire.YAML do
  @moduledoc """
  YAML ingress for canonical UI specs.

  This module parses YAML documents and normalizes them into the same
  canonical `root + elements` shape used everywhere else in the library.
  YAML remains an ingress format only; validation still happens through
  `JsonLiveviewRender.Spec`.
  """

  alias JsonLiveviewRender.Spec.Normalize

  @type parse_result :: {:ok, map()} | {:error, [term()]}

  @atom_like_pattern ~r/^:[A-Za-z_][A-Za-z0-9_]*[!?]?$/

  @doc """
  Parses a YAML document into a canonical `root + elements` spec map.
  """
  @spec parse(String.t()) :: parse_result()
  def parse(yaml) when is_binary(yaml) do
    with {:ok, decoded} <- read_yaml(yaml),
         {:ok, spec_map} <- normalize_document(decoded),
         {:ok, canonical} <- Normalize.canonical(spec_map) do
      {:ok, canonical}
    end
  end

  def parse(_yaml), do: {:error, [{:invalid_yaml, "YAML input must be a string"}]}

  defp read_yaml(yaml) do
    case YamlElixir.read_from_string(yaml, atoms: false) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, [{:invalid_yaml, format_yaml_error(reason)}]}
    end
  end

  defp normalize_document(decoded) when is_map(decoded) do
    decoded
    |> normalize_yaml_keys()
    |> normalize_spec_fields()
    |> then(&{:ok, &1})
  end

  defp normalize_document(_decoded),
    do: {:error, [{:invalid_spec, "YAML document must decode to a map"}]}

  defp normalize_yaml_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} ->
      {normalize_key(key), normalize_yaml_keys(value)}
    end)
  end

  defp normalize_yaml_keys(list) when is_list(list), do: Enum.map(list, &normalize_yaml_keys/1)
  defp normalize_yaml_keys(value), do: value

  defp normalize_spec_fields(spec) do
    spec
    |> maybe_put_normalized("root", &normalize_identifier_value/1)
    |> maybe_put_normalized("elements", &normalize_elements/1)
  end

  defp normalize_elements(elements) when is_map(elements) do
    Map.new(elements, fn {id, element} ->
      {normalize_identifier_value(id), normalize_element(element)}
    end)
  end

  defp normalize_elements(elements), do: elements

  defp normalize_element(%{} = element) do
    element
    |> maybe_put_normalized("type", &normalize_type_value/1)
    |> maybe_put_normalized("children", &normalize_children/1)
  end

  defp normalize_element(element), do: element

  defp maybe_put_normalized(map, key, fun) do
    if Map.has_key?(map, key) do
      Map.update!(map, key, fun)
    else
      map
    end
  end

  defp normalize_children(children) when is_list(children) do
    Enum.map(children, &normalize_identifier_value/1)
  end

  defp normalize_children(children), do: children

  defp normalize_key(key) when is_binary(key), do: normalize_atom_like_string(key)
  defp normalize_key(key), do: key |> safe_to_string() |> normalize_atom_like_string()

  defp normalize_identifier_value(value) when is_binary(value),
    do: normalize_atom_like_string(value)

  defp normalize_identifier_value(value), do: value

  defp normalize_type_value(value) when is_binary(value), do: normalize_atom_like_string(value)
  defp normalize_type_value(value), do: value

  defp normalize_atom_like_string(value) do
    if Regex.match?(@atom_like_pattern, value) do
      String.trim_leading(value, ":")
    else
      value
    end
  end

  defp safe_to_string(value) do
    to_string(value)
  rescue
    _ -> inspect(value)
  end

  defp format_yaml_error(%{message: message}) when is_binary(message), do: message
  defp format_yaml_error(reason) when is_binary(reason), do: reason

  defp format_yaml_error(reason) do
    Exception.message(reason)
  rescue
    _ -> inspect(reason)
  end
end
