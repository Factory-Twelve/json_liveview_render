defmodule JsonLiveviewRender.SpecTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import ExUnit.CaptureLog

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Test.Generators
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "valid spec passes" do
    assert {:ok, _spec} = Spec.validate(valid_spec(), Catalog)
  end

  test "rejects unknown component types" do
    spec = put_in(valid_spec(), ["elements", "metric_1", "type"], "does_not_exist")

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :unknown_component end)
  end

  test "rejects missing required props" do
    spec = update_in(valid_spec(), ["elements", "metric_1", "props"], &Map.delete(&1, "label"))

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :missing_required_prop end)
  end

  test "rejects unresolved child refs" do
    spec = put_in(valid_spec(), ["elements", "page", "children"], ["missing_child"])

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :unresolved_child end)
  end

  test "validate_partial/3 allows unresolved child refs for streaming" do
    spec = put_in(valid_spec(), ["elements", "page", "children"], ["missing_child"])

    assert {:ok, validated} = Spec.validate_partial(spec, Catalog)
    assert validated["root"] == "page"
  end

  test "validate_partial/3 allows missing root while elements stream in" do
    spec = %{"elements" => %{}}
    assert {:ok, %{"root" => nil, "elements" => %{}}} = Spec.validate_partial(spec, Catalog)
  end

  test "validate_partial/3 warns when root is set but root element is not present yet" do
    spec = %{"root" => "page", "elements" => %{}}

    assert capture_log(fn ->
             assert {:ok, _} = Spec.validate_partial(spec, Catalog)
           end) =~ "root \"page\" not yet present"
  end

  test "rejects cycles" do
    spec =
      valid_spec()
      |> put_in(["elements", "metric_1", "children"], ["page"])

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :cycle_detected end)
  end

  test "strict mode rejects unknown props" do
    spec = put_in(valid_spec(), ["elements", "metric_1", "props", "nope"], true)

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :unknown_prop end)
  end

  test "permissive mode allows unknown props" do
    spec = put_in(valid_spec(), ["elements", "metric_1", "props", "nope"], true)

    assert capture_log(fn ->
             assert {:ok, _} = Spec.validate(spec, Catalog, strict: false)
           end) =~ "ignoring unknown prop"
  end

  test "pre-normalized string-key specs do not crash on non-string prop keys" do
    spec = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{{:bad, :key} => true},
          "children" => []
        }
      }
    }

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert is_list(reasons)
  end

  test "pre-normalized specs with atom root do not crash on malformed nested keys" do
    spec = %{
      "root" => :metric_1,
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{{:bad, :key} => true},
          "children" => []
        }
      }
    }

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :invalid_root_type end)
  end

  property "acyclic linear chain specs validate" do
    check all(spec <- Generators.valid_linear_spec(max_len: 20)) do
      assert {:ok, _} = Spec.validate(spec, Catalog)
    end
  end

  property "adding a back-edge produces cycle errors" do
    check all(spec <- Generators.cyclic_linear_spec(max_len: 20)) do
      assert {:error, reasons} = Spec.validate(spec, Catalog)
      assert Enum.any?(reasons, fn {tag, _} -> tag == :cycle_detected end)
    end
  end

  defp valid_spec do
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
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }
  end
end
