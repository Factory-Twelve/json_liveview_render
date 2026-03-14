defmodule JsonLiveviewRender.Wire.YAMLTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Wire.YAML
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  defmodule StyledMetricCatalog do
    use JsonLiveviewRender.Catalog

    component :styled_metric do
      description("Metric with nested style config")
      prop(:label, :string, required: true)
      prop(:value, :string, required: true)
      prop(:style, :map, required: true)
    end
  end

  test "parse/1 normalizes a YAML spec into the canonical root + elements shape" do
    assert {:ok, normalized} = fixture("basic_spec.yaml") |> YAML.parse()

    assert normalized == %{
             "root" => "page",
             "elements" => %{
               "page" => %{
                 "type" => "column",
                 "props" => %{"gap" => "md"},
                 "children" => ["metric_1"]
               },
               "metric_1" => %{
                 "type" => "metric",
                 "props" => %{"label" => "Revenue", "value" => "$100"},
                 "children" => []
               }
             }
           }

    assert {:ok, ^normalized} = Spec.validate(normalized, Catalog)
  end

  test "parse/1 stringifies numeric and boolean-like ids while preserving child order" do
    yaml = """
    root: 100
    elements:
      100:
        type: column
        props:
          gap: md
        children:
          - 200
          - false
      200:
        type: metric
        props:
          label: Revenue
          value: "$100"
        children: []
      false:
        type: metric
        props:
          label: Health
          value: Green
        children: []
    """

    assert {:ok, normalized} = YAML.parse(yaml)
    assert normalized["root"] == "100"
    assert normalized["elements"]["100"]["children"] == ["200", "false"]
    assert Map.has_key?(normalized["elements"], "false")
    assert {:ok, ^normalized} = Spec.validate(normalized, Catalog)
  end

  test "parse/1 normalizes atom-like keys and nested prop maps before validation" do
    assert {:ok, normalized} = fixture("nested_props_spec.yaml") |> YAML.parse()

    assert normalized["root"] == "page"
    assert normalized["elements"]["page"]["children"] == ["metric_1", "metric_2"]

    assert normalized["elements"]["metric_1"]["props"]["style"] == %{
             "layout" => %{
               "padding" => %{"top" => 24, "bottom" => 12},
               "badge" => %{"tone" => "positive"}
             }
           }

    assert {:ok, ^normalized} = Spec.validate(normalized, StyledMetricCatalog)
  end

  test "parse/1 returns an explicit error for invalid YAML" do
    yaml = """
    root: page
    elements:
      page:
        type: column
        props:
          gap: md
        children: [metric_1
    """

    assert {:error, [{:invalid_yaml, message}]} = YAML.parse(yaml)
    assert is_binary(message)
    assert message != ""
  end

  test "parsed YAML still fails through the canonical validator when required fields are missing" do
    yaml = """
    elements:
      page:
        type: column
        props:
          gap: md
        children: []
    """

    assert {:ok, normalized} = YAML.parse(yaml)
    assert {:error, reasons} = Spec.validate(normalized, Catalog)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :root_missing end)
  end

  defp fixture(name) do
    Path.expand("../../fixtures/wire/#{name}", __DIR__)
    |> File.read!()
  end
end
