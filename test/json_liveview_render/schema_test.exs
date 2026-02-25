defmodule JsonLiveviewRender.SchemaTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Schema
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "exports JSON schema with root/elements and component variants" do
    schema = Schema.to_json_schema(Catalog)

    assert schema["type"] == "object"
    assert schema["properties"]["root"]["type"] == "string"

    variants = schema["properties"]["elements"]["additionalProperties"]["oneOf"]
    assert is_list(variants)

    assert Enum.any?(variants, fn variant ->
             get_in(variant, ["properties", "type", "const"]) == "metric"
           end)
  end

  test "schema includes component descriptions" do
    schema = Schema.to_json_schema(Catalog)

    variants = schema["properties"]["elements"]["additionalProperties"]["oneOf"]

    metric_variant =
      Enum.find(variants, fn variant ->
        get_in(variant, ["properties", "type", "const"]) == "metric"
      end)

    assert get_in(metric_variant, ["properties", "type", "description"]) == "Single KPI"
  end

  test "exports prompt text with component and prop usage" do
    prompt = Schema.to_prompt(Catalog)

    assert prompt =~ "Available components"
    assert prompt =~ "### metric"
    assert prompt =~ "label"
    assert prompt =~ "rows_binding"
  end
end
