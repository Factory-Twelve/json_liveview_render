defmodule JsonLiveviewRender.Schema.PromptBuilder do
  @moduledoc false

  alias JsonLiveviewRender.Catalog.ComponentDef
  alias JsonLiveviewRender.Catalog.PropDef

  @spec build(module()) :: String.t()
  def build(catalog_module) do
    components_text =
      catalog_module.components()
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
      |> Enum.map(fn {prop_name, prop_def} -> "- #{prop_line(prop_name, prop_def)}" end)
      |> Enum.join("\n")

    permission_text =
      case component.permission do
        nil -> "any authenticated user"
        role -> Atom.to_string(role)
      end

    [
      "### #{Atom.to_string(type)}",
      component.description || "No description",
      "Permission: #{permission_text}",
      "Props:",
      if(props == "", do: "- none", else: props)
    ]
    |> Enum.join("\n")
  end

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
