defmodule JsonLiveviewRender.Wire.MergePatchTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Wire.MergePatch
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  @fixtures_dir Path.expand("../../fixtures/wire/merge_patch", __DIR__)

  test "apply/2 merges element props from a fixture patch" do
    assert {:ok, patched} = MergePatch.apply(base_spec(), fixture_patch("replace_props.json"))

    assert patched["elements"]["metric_1"]["props"] == %{
             "label" => "Revenue",
             "value" => "$125",
             "trend" => "up"
           }
  end

  test "apply/2 removes nested props when the patch value is null" do
    assert {:ok, patched} =
             MergePatch.apply(base_spec(), fixture_patch("remove_element_props.json"))

    refute Map.has_key?(patched["elements"]["metric_1"]["props"], "trend")
    assert patched["elements"]["metric_1"]["props"]["label"] == "Revenue"
    assert patched["elements"]["metric_1"]["props"]["value"] == "$100"
  end

  test "apply/2 removes element entries when the patch sets them to null" do
    assert {:ok, patched} =
             MergePatch.apply(two_metric_spec(), %{"elements" => %{"metric_2" => nil}})

    refute Map.has_key?(patched["elements"], "metric_2")
    assert patched["elements"]["page"]["children"] == ["metric_1", "metric_2"]
  end

  test "apply/2 replaces children arrays atomically" do
    assert {:ok, patched} =
             MergePatch.apply(two_metric_spec(), %{
               "elements" => %{
                 "page" => %{"children" => ["metric_2"]}
               }
             })

    assert patched["elements"]["page"]["children"] == ["metric_2"]
  end

  test "apply_and_validate/4 fails complete validation when the patch removes root" do
    assert {:error, reasons} =
             MergePatch.apply_and_validate(base_spec(), %{"root" => nil}, Catalog)

    assert Enum.any?(reasons, fn {tag, _message} -> tag == :root_missing end)
  end

  test "apply_and_validate/4 can revalidate the patched document in partial mode" do
    assert {:ok, patched} =
             MergePatch.apply_and_validate(base_spec(), %{"root" => nil}, Catalog,
               validation: :partial
             )

    assert patched["root"] == nil
    assert Map.has_key?(patched["elements"], "page")
  end

  test "apply_and_validate/4 surfaces canonical validation errors after element removal" do
    assert {:error, reasons} =
             MergePatch.apply_and_validate(
               base_spec(),
               %{"elements" => %{"metric_1" => nil}},
               Catalog
             )

    assert Enum.any?(reasons, fn {tag, _message} -> tag == :unresolved_child end)
  end

  defp fixture_patch(filename) do
    @fixtures_dir
    |> Path.join(filename)
    |> File.read!()
    |> Jason.decode!()
  end

  defp base_spec do
    %{
      "root" => "page",
      "elements" => %{
        "page" => %{
          "type" => "row",
          "props" => %{"gap" => "md"},
          "children" => ["metric_1"]
        },
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100", "trend" => "flat"},
          "children" => []
        }
      }
    }
  end

  defp two_metric_spec do
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
          "props" => %{"label" => "Margin", "value" => "35%"},
          "children" => []
        }
      }
    }
  end
end
