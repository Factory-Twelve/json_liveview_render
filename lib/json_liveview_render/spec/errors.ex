defmodule JsonLiveviewRender.Spec.Errors do
  @moduledoc "Error constructors for `JsonLiveviewRender.Spec` validation."

  @doc "Error: spec has no `root` key."
  @spec root_missing() :: {:root_missing, String.t()}
  def root_missing, do: {:root_missing, "spec must include a root key"}

  @doc "Error: spec has no `elements` map."
  @spec elements_missing() :: {:elements_missing, String.t()}
  def elements_missing, do: {:elements_missing, "spec must include an elements map"}

  @doc "Error: root references an element not present in `elements`."
  @spec root_not_found(String.t()) :: {:root_not_found, String.t()}
  def root_not_found(root), do: {:root_not_found, "root element #{inspect(root)} was not found"}

  @doc "Error: element value is not a map."
  @spec invalid_element(String.t()) :: {:invalid_element, String.t()}
  def invalid_element(id), do: {:invalid_element, "element #{inspect(id)} must be a map"}

  @doc "Error: element is missing a `type` field."
  @spec missing_type(String.t()) :: {:missing_type, String.t()}
  def missing_type(id), do: {:missing_type, "element #{inspect(id)} is missing type"}

  @doc "Error: element references a component type not in the catalog."
  @spec unknown_component(String.t(), String.t()) :: {:unknown_component, String.t()}
  def unknown_component(id, type),
    do:
      {:unknown_component, "element #{inspect(id)} references unknown component #{inspect(type)}"}

  @doc "Error: element children is not a list of string IDs."
  @spec invalid_children_type(String.t()) :: {:invalid_children_type, String.t()}
  def invalid_children_type(id),
    do: {:invalid_children_type, "element #{inspect(id)} children must be a list of ids"}

  @doc "Error: element references a child ID not present in `elements`."
  @spec unresolved_child(String.t(), term()) :: {:unresolved_child, String.t()}
  def unresolved_child(id, child),
    do: {:unresolved_child, "element #{inspect(id)} references missing child #{inspect(child)}"}

  @doc "Error: a cycle was detected in the element graph."
  @spec cycle_detected([String.t()]) :: {:cycle_detected, String.t()}
  def cycle_detected(path),
    do: {:cycle_detected, "cycle detected in spec graph: #{Enum.join(path, " -> ")}"}

  @doc "Error: a required prop is missing from an element."
  @spec missing_required_prop(String.t(), String.t()) :: {:missing_required_prop, String.t()}
  def missing_required_prop(id, prop),
    do: {:missing_required_prop, "element #{inspect(id)} missing required prop #{inspect(prop)}"}

  @doc "Error: element includes a prop not defined in the catalog."
  @spec unknown_prop(String.t(), String.t()) :: {:unknown_prop, String.t()}
  def unknown_prop(id, prop),
    do: {:unknown_prop, "element #{inspect(id)} includes unknown prop #{inspect(prop)}"}

  @doc "Error: a prop value does not match the expected type."
  @spec invalid_prop_type(String.t(), String.t(), atom(), term()) ::
          {:invalid_prop_type, String.t()}
  def invalid_prop_type(id, prop, expected, actual) do
    {:invalid_prop_type,
     "element #{inspect(id)} prop #{inspect(prop)} expected #{inspect(expected)}, got #{inspect(actual)}"}
  end

  @doc """
  Formats a list of validation errors into a human-readable string suitable
  for feeding back to an AI for re-prompting.
  """
  @spec format_errors([term()]) :: String.t()
  def format_errors(errors) when is_list(errors) do
    lines = Enum.map(errors, &format_error_tuple/1)
    "The generated UI spec has the following errors:\n" <> Enum.join(lines, "\n")
  end

  @doc """
  Formats validation errors with catalog context. `:unknown_component` errors
  are enriched with the list of available component types from the catalog.
  """
  @spec format_errors([term()], module()) :: String.t()
  def format_errors(errors, catalog) when is_list(errors) do
    lines = Enum.map(errors, &format_error_tuple(&1, catalog))
    "The generated UI spec has the following errors:\n" <> Enum.join(lines, "\n")
  end

  defp format_error_tuple({:unknown_component, _msg} = error, catalog) do
    available = catalog.types() |> Enum.map(&to_string/1) |> Enum.join(", ")
    "- " <> elem(error, 1) <> " (available types: #{available})"
  end

  defp format_error_tuple(error, _catalog), do: format_error_tuple(error)

  defp format_error_tuple({_tag, message}) when is_binary(message), do: "- " <> message
  defp format_error_tuple(other), do: "- " <> inspect(other)
end
