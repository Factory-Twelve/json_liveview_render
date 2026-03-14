defmodule JsonLiveviewRender.Wire.JsonPatchTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Wire.JsonPatch
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "adds a nested prop on a canonicalized spec" do
    spec = %{
      root: :page,
      elements: %{
        page: %{
          type: :row,
          props: %{gap: "md"},
          children: [:metric_1, :metric_2]
        },
        metric_1: %{
          type: :metric,
          props: %{label: "Revenue", value: "$100"},
          children: []
        },
        metric_2: %{
          type: :metric,
          props: %{label: "Margin", value: "10%"},
          children: []
        }
      }
    }

    patch = [%{op: :add, path: "/elements/metric_1/props/trend", value: "up"}]

    assert {:ok, patched} = JsonPatch.apply(spec, patch, Catalog)
    assert patched["elements"]["metric_1"]["props"]["trend"] == "up"
  end

  test "allows top-level add operations when root and elements were absent in the input spec" do
    patch = [
      %{
        "op" => "add",
        "path" => "/elements",
        "value" => %{
          "page" => %{
            "type" => "row",
            "props" => %{"gap" => "md"},
            "children" => []
          }
        }
      },
      %{"op" => "add", "path" => "/root", "value" => "page"}
    ]

    assert {:ok, patched} = JsonPatch.apply(%{}, patch, Catalog)
    assert patched["root"] == "page"
    assert patched["elements"]["page"]["type"] == "row"
  end

  test "removes a single child ref from the canonical array fixture" do
    assert {:ok, patched} =
             JsonPatch.apply(valid_spec(), fixture_patch("remove_child_ref.json"), Catalog)

    assert patched["elements"]["page"]["children"] == ["metric_2"]
  end

  test "replaces one child entry without replacing the whole array" do
    patch = [
      %{
        "op" => "replace",
        "path" => "/elements/page/children/1",
        "value" => "metric_3"
      },
      %{
        "op" => "add",
        "path" => "/elements/metric_3",
        "value" => %{
          "type" => "metric",
          "props" => %{"label" => "Forecast", "value" => "$110"},
          "children" => []
        }
      }
    ]

    assert {:ok, patched} = JsonPatch.apply(valid_spec(), patch, Catalog)
    assert patched["elements"]["page"]["children"] == ["metric_1", "metric_3"]
    assert patched["elements"]["metric_1"]["props"]["label"] == "Revenue"
  end

  test "supports escaped element ids in elements paths" do
    patch = [
      %{
        "op" => "add",
        "path" => "/elements/metric~11",
        "value" => %{
          "type" => "metric",
          "props" => %{"label" => "Forecast", "value" => "$110"},
          "children" => []
        }
      },
      %{"op" => "add", "path" => "/elements/page/children/-", "value" => "metric/1"}
    ]

    assert {:ok, patched} = JsonPatch.apply(valid_spec(), patch, Catalog)
    assert patched["elements"]["page"]["children"] == ["metric_1", "metric_2", "metric/1"]
    assert patched["elements"]["metric/1"]["props"]["label"] == "Forecast"
  end

  test "supports escaped prop names in props paths before validation runs" do
    patch = [
      %{
        "op" => "add",
        "path" => "/elements/metric_1/props/title~1short",
        "value" => "Quarterly Revenue"
      }
    ]

    assert {:error, reasons} = JsonPatch.apply(valid_spec(), patch, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :unknown_prop end)
  end

  test "fails explicitly on unsupported operations" do
    patch = [%{"op" => "copy", "path" => "/root", "from" => "/elements/page"}]

    assert {:error, [{:unsupported_patch_operation, _message}]} =
             JsonPatch.apply(valid_spec(), patch, Catalog)
  end

  test "fails when a nested path targets a missing intermediate map" do
    patch = [
      %{"op" => "remove", "path" => "/elements/metric_1/props"},
      %{"op" => "add", "path" => "/elements/metric_1/props/trend", "value" => "up"}
    ]

    assert {:error, [{:patch_path_not_found, _message}]} =
             JsonPatch.apply(valid_spec(), patch, Catalog)
  end

  test "fails through spec validation when the patch makes the spec invalid" do
    assert {:error, reasons} =
             JsonPatch.apply(valid_spec(), fixture_patch("add_metric_title.json"), Catalog)

    assert Enum.any?(reasons, fn {tag, _} -> tag == :unknown_prop end)
  end

  test "removing root fails in complete mode and succeeds in accumulation mode" do
    patch = [%{"op" => "remove", "path" => "/root"}]

    assert {:error, reasons} = JsonPatch.apply(valid_spec(), patch, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :root_missing end)

    assert {:ok, patched} =
             JsonPatch.apply(valid_spec(), patch, Catalog, allow_missing_root: true)

    assert patched["root"] == nil
  end

  test "fails explicitly when add targets an existing object member" do
    patch = [%{"op" => "add", "path" => "/elements/metric_1/props/value", "value" => "$101"}]

    assert {:error, [{:patch_path_exists, _message}]} =
             JsonPatch.apply(valid_spec(), patch, Catalog)
  end

  test "rejects signed array indexes instead of coercing them" do
    patch = [%{"op" => "replace", "path" => "/elements/page/children/-0", "value" => "metric_2"}]

    assert {:error, [{:invalid_patch_index, _message}]} =
             JsonPatch.apply(valid_spec(), patch, Catalog)
  end

  test "returns an error when add targets an out-of-range child index" do
    patch = [%{"op" => "add", "path" => "/elements/page/children/9", "value" => "metric_3"}]

    assert {:error, [{:invalid_patch_index, _message}]} =
             JsonPatch.apply(valid_spec(), patch, Catalog)
  end

  test "returns an error when replace targets a missing child index" do
    patch = [%{"op" => "replace", "path" => "/elements/page/children/9", "value" => "metric_2"}]

    assert {:error, [{:patch_path_not_found, _message}]} =
             JsonPatch.apply(valid_spec(), patch, Catalog)
  end

  defp fixture_patch(filename) do
    filename
    |> fixture_path()
    |> File.read!()
    |> Jason.decode!()
  end

  defp fixture_path(filename) do
    Path.expand("../../fixtures/wire/json_patch/#{filename}", __DIR__)
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
          "props" => %{"label" => "Margin", "value" => "10%"},
          "children" => []
        }
      }
    }
  end
end
