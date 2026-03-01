defmodule JsonLiveviewRender.Schema.PromptBuilder do
  @moduledoc false

  alias JsonLiveviewRender.Catalog.ComponentDef
  alias JsonLiveviewRender.Catalog.PropDef

  @spec build(module()) :: String.t()
  def build(catalog_module) do
    components_text =
      catalog_module.components()
      |> Enum.sort_by(fn {type, _component} -> Atom.to_string(type) end)
      |> Enum.map(fn {type, component} -> component_prompt(type, component) end)
      |> Enum.join("\n\n")

    """
    You generate UI specs for a Phoenix LiveView application.

    Output format:
    - JSON object with "root" and "elements"
    - "elements" is a flat map keyed by element ids
    - each element contains: "type", "props", optional "children"

    Available components:
    #{components_text}
    """
    |> String.trim()
  end

  defp component_prompt(type, %ComponentDef{} = component) do
    props =
      component.props
      |> Enum.sort_by(fn {prop_name, _prop_def} -> Atom.to_string(prop_name) end)
      |> Enum.map(fn {prop_name, prop_def} -> "- #{prop_line(prop_name, prop_def)}" end)
      |> Enum.join("\n")

    permission_text = permissions_text(component.permission)

    [
      "### #{Atom.to_string(type)}",
      component.description || "No description",
      "Permission: #{permission_text}",
      "Props:",
      if(props == "", do: "- none", else: props)
    ]
    |> Enum.join("\n")
  end

  defp permissions_text(nil), do: "any authenticated user"

  defp permissions_text(permission) when is_atom(permission), do: Atom.to_string(permission)

  defp permissions_text(permission) when is_binary(permission), do: permission

  defp permissions_text(permission) when is_list(permission) do
    "any_of(#{format_role_list(permission)})"
  end

  defp permissions_text(permission) when is_map(permission) do
    cond do
      Map.has_key?(permission, :any_of) ->
        "any_of(#{format_role_list(Map.fetch!(permission, :any_of))}#{format_deny_clause(Map.get(permission, :deny, []))})"

      Map.has_key?(permission, :all_of) ->
        "all_of(#{format_role_list(Map.fetch!(permission, :all_of))}#{format_deny_clause(Map.get(permission, :deny, []))})"

      true ->
        "invalid permission policy: #{inspect(permission)}"
    end
  end

  defp permissions_text(permission), do: inspect(permission)

  defp format_role_list(roles) when is_list(roles),
    do: "[" <> Enum.map_join(roles, ", ", &to_string/1) <> "]"

  defp format_role_list(roles), do: inspect(roles)

  defp format_deny_clause([]), do: ""
  defp format_deny_clause(deny_roles), do: ", deny: #{format_role_list(deny_roles)}"

  defp prop_line(prop_name, %PropDef{} = prop_def) do
    req = if prop_def.required, do: "required", else: "optional"
    type = type_to_text(prop_def.type, prop_def.values)

    [Atom.to_string(prop_name), "(#{type}, #{req})", doc_text(prop_def.doc)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
  end

  defp type_to_text(:enum, values), do: "enum: #{Enum.map_join(values || [], ", ", &to_string/1)}"
  defp type_to_text({:list, inner}, _values), do: "list<#{type_to_text(inner, nil)}>"
  defp type_to_text(type, _values), do: to_string(type)

  defp doc_text(nil), do: nil
  defp doc_text(doc), do: "- #{doc}"
end
