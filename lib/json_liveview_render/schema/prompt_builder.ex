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
    "any_of(#{permission |> Enum.map_join(", ", &to_string/1)})"
  end

  defp permissions_text(permission) when is_map(permission) do
    cond do
      Map.has_key?(permission, :any_of) ->
        any_of = permission |> Map.fetch!(:any_of) |> join_roles()
        deny = join_roles(Map.get(permission, :deny, []), " deny")
        "any_of(#{any_of})#{deny}"

      Map.has_key?(permission, :all_of) ->
        all_of = permission |> Map.fetch!(:all_of) |> join_roles()
        deny = join_roles(Map.get(permission, :deny, []), " deny")
        "all_of(#{all_of})#{deny}"

      true ->
        "invalid permission policy: #{inspect(permission)}"
    end
  end

  defp permissions_text(permission), do: inspect(permission)

  defp join_roles(roles, suffix \\ "") when is_list(roles) do
    case roles do
      [] ->
        ""

      [head | _tail] when is_binary(head) ->
        roles_str = Enum.map_join(roles, ", ", &to_string/1)
        "#{suffix}: [#{roles_str}]"

      [head | _tail] when is_atom(head) ->
        roles_str = Enum.map_join(roles, ", ", &Atom.to_string/1)
        "#{suffix}: [#{roles_str}]"

      _ ->
        "#{suffix}: [#{inspect(roles)}]"
    end
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
