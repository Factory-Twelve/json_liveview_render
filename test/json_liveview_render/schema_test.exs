defmodule JsonLiveviewRender.SchemaTest do
  use ExUnit.Case, async: true

  doctest JsonLiveviewRender.Schema

  alias JsonLiveviewRender.Schema
  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRenderTest.SchemaFixtures.MediumCatalog
  alias JsonLiveviewRenderTest.SchemaFixtures.SmallCatalog

  test "small catalog export matches golden schema and prompt fixtures" do
    assert fixture_json("small_catalog.json") == Schema.to_json_schema(SmallCatalog)
    assert fixture_text("small_prompt.txt") == Schema.to_prompt(SmallCatalog)
  end

  test "medium catalog export matches golden schema fixture and includes strictness assumptions" do
    schema = Schema.to_json_schema(MediumCatalog)
    assert fixture_json("medium_catalog.json") == schema

    assert is_list(get_in(schema, ["properties", "elements", "additionalProperties", "oneOf"]))

    metric_variant =
      schema["properties"]["elements"]["additionalProperties"]["oneOf"]
      |> Enum.find(fn variant -> get_in(variant, ["properties", "type", "const"]) == "metric" end)

    assert get_in(metric_variant, ["properties", "props", "required"]) == ["label", "value"]

    assert get_in(metric_variant, ["properties", "props", "properties", "trend", "enum"]) == [
             "up",
             "down",
             "flat"
           ]

    assert metric_variant["required"] == ["type", "props"]
    assert metric_variant["additionalProperties"] == false
  end

  test "medium prompt output is stable and includes role/prop semantics" do
    assert fixture_text("medium_prompt.txt") == Schema.to_prompt(MediumCatalog)

    prompt = Schema.to_prompt(MediumCatalog)
    assert String.contains?(prompt, "Permission: member")
    assert String.contains?(prompt, "Permission: admin")
    assert String.contains?(prompt, "label (string, required)")
    assert String.contains?(prompt, "rows_binding (string, required)")
    assert String.contains?(prompt, "show_totals (boolean, optional)")
    assert String.contains?(prompt, "\n### admin_panel")
  end

  test "strict validator rejects unknown props consistent with schema additionalProperties false" do
    strict_spec = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$10", "unknown_prop" => true},
          "children" => []
        }
      }
    }

    assert {:error, reasons} = Spec.validate(strict_spec, MediumCatalog)
    assert Enum.any?(reasons, fn {reason, _} -> reason == :unknown_prop end)
    assert {:ok, _} = Spec.validate(strict_spec, MediumCatalog, strict: false)
  end

  defp fixture_json(filename) do
    filename
    |> fixture_path()
    |> File.read!()
    |> Jason.decode!()
  end

  defp fixture_text(filename) do
    filename
    |> fixture_path()
    |> File.read!()
    |> String.trim()
  end

  defp fixture_path(filename) do
    Path.join(fixtures_dir(), filename)
  end

  defp fixtures_dir do
    Path.expand("../fixtures/schema", __DIR__)
  end
end
