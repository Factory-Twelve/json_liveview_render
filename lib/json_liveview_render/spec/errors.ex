defmodule JsonLiveviewRender.Spec.Errors do
  @moduledoc "Error constructors for `JsonLiveviewRender.Spec` validation."

  def root_missing, do: {:root_missing, "spec must include a root key"}
  def elements_missing, do: {:elements_missing, "spec must include an elements map"}
  def root_not_found(root), do: {:root_not_found, "root element #{inspect(root)} was not found"}
  def invalid_element(id), do: {:invalid_element, "element #{inspect(id)} must be a map"}
  def missing_type(id), do: {:missing_type, "element #{inspect(id)} is missing type"}

  def unknown_component(id, type),
    do:
      {:unknown_component, "element #{inspect(id)} references unknown component #{inspect(type)}"}

  def invalid_children_type(id),
    do: {:invalid_children_type, "element #{inspect(id)} children must be a list of ids"}

  def unresolved_child(id, child),
    do: {:unresolved_child, "element #{inspect(id)} references missing child #{inspect(child)}"}

  def cycle_detected(path),
    do: {:cycle_detected, "cycle detected in spec graph: #{Enum.join(path, " -> ")}"}

  def missing_required_prop(id, prop),
    do: {:missing_required_prop, "element #{inspect(id)} missing required prop #{inspect(prop)}"}

  def unknown_prop(id, prop),
    do: {:unknown_prop, "element #{inspect(id)} includes unknown prop #{inspect(prop)}"}

  def invalid_prop_type(id, prop, expected, actual) do
    {:invalid_prop_type,
     "element #{inspect(id)} prop #{inspect(prop)} expected #{inspect(expected)}, got #{inspect(actual)}"}
  end
end
