defmodule JsonLiveviewRender.Schema.JSONSchemaBuilder do
  @moduledoc false

  alias JsonLiveviewRender.Catalog.ComponentDef
  alias JsonLiveviewRender.Catalog.PropDef

  @spec build(module()) :: map()
  def build(catalog_module) do
    component_variants =
      catalog_module.components()
      |> Enum.map(fn {type, %ComponentDef{} = component} ->
        element_variant_schema(type, component)
      end)

    %{
      "$schema" => "https://json-schema.org/draft/2020-12/schema",
      "title" => "JsonLiveviewRender Spec",
      "type" => "object",
      "required" => ["root", "elements"],
      "additionalProperties" => false,
      "properties" => %{
        "root" => %{"type" => "string"},
        "elements" => %{
          "type" => "object",
          "additionalProperties" => %{
            "oneOf" => component_variants
          }
        }
      }
    }
  end

  defp element_variant_schema(type, %ComponentDef{} = component) do
    %{
      "type" => "object",
      "required" => ["type", "props"],
      "additionalProperties" => false,
      "properties" => %{
        "type" => %{
          "const" => Atom.to_string(type),
          "description" => component.description || ""
        },
        "props" => props_schema(component),
        "children" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "default" => []
        }
      }
    }
  end

  defp props_schema(%ComponentDef{props: props}) do
    properties =
      Map.new(props, fn {name, prop_def} ->
        {Atom.to_string(name), prop_schema(prop_def)}
      end)

    required =
      props
      |> Enum.filter(fn {_name, %PropDef{required: required?}} -> required? end)
      |> Enum.map(fn {name, _} -> Atom.to_string(name) end)

    base = %{
      "type" => "object",
      "additionalProperties" => false,
      "properties" => properties
    }

    if required == [] do
      base
    else
      Map.put(base, "required", required)
    end
  end

  defp prop_schema(%PropDef{type: :string, doc: doc, default: default}),
    do: annotate(%{"type" => "string"}, doc, default)

  defp prop_schema(%PropDef{type: :integer, doc: doc, default: default}),
    do: annotate(%{"type" => "integer"}, doc, default)

  defp prop_schema(%PropDef{type: :float, doc: doc, default: default}),
    do: annotate(%{"type" => "number"}, doc, default)

  defp prop_schema(%PropDef{type: :boolean, doc: doc, default: default}),
    do: annotate(%{"type" => "boolean"}, doc, default)

  defp prop_schema(%PropDef{type: :map, doc: doc, default: default}),
    do: annotate(%{"type" => "object"}, doc, default)

  defp prop_schema(%PropDef{type: :enum, values: values, doc: doc, default: default}) do
    enum_values = Enum.map(values || [], &enum_json_value/1)
    annotate(%{"enum" => enum_values}, doc, enum_json_value(default))
  end

  defp prop_schema(%PropDef{type: {:list, inner_type}, doc: doc, default: default}) do
    annotate(
      %{"type" => "array", "items" => prop_schema(%PropDef{name: :item, type: inner_type})},
      doc,
      default
    )
  end

  defp prop_schema(%PropDef{type: :custom, doc: doc, default: default}),
    do: annotate(%{}, doc, default)

  defp annotate(schema, doc, default) do
    schema
    |> maybe_put("description", doc)
    |> maybe_put("default", default)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp enum_json_value(value) when is_atom(value), do: Atom.to_string(value)
  defp enum_json_value(value), do: value
end
