defmodule JsonLiveviewRender.DebugTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Debug
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "inspect_spec/3 returns summary report for valid specs" do
    assert {:ok, report} = Debug.inspect_spec(valid_spec(), Catalog)

    assert report.root == "page"
    assert report.element_count == 3
    assert report.reachable_count == 3
    assert report.orphan_ids == []
    assert report.max_depth == 1
    assert report.leaf_ids == ["metric_1", "metric_2"]
    assert report.component_counts == %{"metric" => 2, "row" => 1}
    assert report.spec["root"] == "page"
  end

  test "inspect_spec/3 flags orphans in a valid graph" do
    spec =
      put_in(valid_spec(), ["elements", "orphan"], %{
        "type" => "metric",
        "props" => %{"label" => "Orphan", "value" => "0"},
        "children" => []
      })

    assert {:ok, report} = Debug.inspect_spec(spec, Catalog)
    assert report.orphan_ids == ["orphan"]
    assert report.reachable_count == 3
    assert report.element_count == 4
  end

  test "inspect_spec/3 returns validation errors for invalid specs" do
    invalid = put_in(valid_spec(), ["elements", "metric_1", "type"], "unknown")
    assert {:error, reasons} = Debug.inspect_spec(invalid, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :unknown_component end)
  end

  defp valid_spec do
    %{
      "root" => "page",
      "elements" => %{
        "page" => %{
          "type" => "row",
          "props" => %{"gap" => "md"},
          "children" => ["metric_1", "metric_2"]
        },
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        },
        "metric_2" => %{
          "type" => "metric",
          "props" => %{"label" => "Cost", "value" => "$50"},
          "children" => []
        }
      }
    }
  end
end
