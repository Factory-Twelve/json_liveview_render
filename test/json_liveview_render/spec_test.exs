defmodule JsonLiveviewRender.SpecTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import ExUnit.CaptureLog

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Test.Generators
  alias JsonLiveviewRenderTest.Fixtures.Catalog
  alias JsonLiveviewRenderTest.Fixtures.ManualCatalog

  test "valid spec passes" do
    assert {:ok, _spec} = Spec.validate(valid_spec(), Catalog)
  end

  test "validate/2 accepts manual catalogs built from raw component defs" do
    spec = %{
      "root" => "metric_1",
      "elements" => %{
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }

    assert {:ok, validated} = Spec.validate(spec, ManualCatalog)
    assert validated["elements"]["metric_1"]["props"]["label"] == "Revenue"
  end

  test "rejects missing root" do
    spec = Map.delete(valid_spec(), "root")

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :root_missing end)
  end

  test "rejects JSON strings that decode to non-object values" do
    Enum.each(["[]", "123", "null", "true"], fn payload ->
      assert {:error, reasons} = Spec.validate(payload, Catalog)
      assert Enum.any?(reasons, fn {tag, _} -> tag == :invalid_spec end)
    end)
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

  test "validate/2 coerces atom-keyed root, element ids, and nested element fields" do
    spec = %{
      root: :page,
      elements: %{
        page: %{
          type: :row,
          props: %{gap: "md"},
          children: [:metric_1]
        },
        metric_1: %{
          type: :metric,
          props: %{label: "Revenue", value: "$100"},
          children: []
        }
      }
    }

    assert {:ok, normalized} = Spec.validate(spec, Catalog)

    assert normalized == %{
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

  test "validate/2 normalizes mixed-key nested elements when top-level keys are already strings" do
    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{
          type: :row,
          props: %{gap: "md"},
          children: [:metric_1]
        },
        "metric_1" => %{
          type: :metric,
          props: %{label: "Revenue", value: "$100"},
          children: []
        }
      }
    }

    assert {:ok, normalized} = Spec.validate(spec, Catalog)

    assert normalized["elements"]["page"] == %{
             "type" => "row",
             "props" => %{"gap" => "md"},
             "children" => ["metric_1"]
           }
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
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :unknown_prop end)
  end

  test "rejects duplicate child references from the same parent" do
    spec = put_in(valid_spec(), ["elements", "page", "children"], ["metric_1", "metric_1"])

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :duplicate_child end)
  end

  test "reports one duplicate child error per repeated child id" do
    spec =
      put_in(valid_spec(), ["elements", "page", "children"], [
        "metric_1",
        "metric_1",
        "metric_1"
      ])

    assert {:error, reasons} = Spec.validate(spec, Catalog)

    duplicate_errors =
      Enum.filter(reasons, fn {tag, _} -> tag == :duplicate_child end)

    assert length(duplicate_errors) == 1
  end

  test "rejects non-root elements with multiple parents" do
    spec =
      valid_spec()
      |> put_in(["elements", "page", "children"], ["metric_1", "metric_2"])
      |> put_in(["elements", "metric_2"], %{
        "type" => "row",
        "props" => %{"gap" => "md"},
        "children" => ["metric_1"]
      })

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :multiple_parents end)
  end

  test "rejects unreachable elements in complete validation" do
    spec =
      put_in(valid_spec(), ["elements", "orphan"], %{
        "type" => "metric",
        "props" => %{"label" => "Ghost", "value" => "0"},
        "children" => []
      })

    assert {:error, reasons} = Spec.validate(spec, Catalog)
    assert Enum.any?(reasons, fn {tag, _} -> tag == :unreachable_element end)
  end

  test "validate_partial/3 tolerates temporarily unreachable elements during streaming" do
    spec =
      put_in(valid_spec(), ["elements", "orphan"], %{
        "type" => "metric",
        "props" => %{"label" => "Ghost", "value" => "0"},
        "children" => []
      })

    assert {:ok, validated} = Spec.validate_partial(spec, Catalog)
    assert Map.has_key?(validated["elements"], "orphan")
  end

  test "validate_partial/3 defers multiple-parent checks for unresolved child ids" do
    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{"type" => "row", "props" => %{}, "children" => ["future"]},
        "sidebar" => %{"type" => "row", "props" => %{}, "children" => ["future"]}
      }
    }

    assert {:ok, validated} = Spec.validate_partial(spec, Catalog)
    assert Map.keys(validated["elements"]) |> Enum.sort() == ["page", "sidebar"]
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
