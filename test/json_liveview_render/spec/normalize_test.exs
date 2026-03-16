defmodule JsonLiveviewRender.Spec.NormalizeTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Spec.Normalize
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  test "canonical/1 produces deterministic root + elements output from mixed atom and string keys" do
    spec = %{
      root: :page,
      elements: %{
        :page => %{
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

    assert {:ok, normalized} = Normalize.canonical(spec)

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

  test "canonical/1 normalizes nested element data even when top-level keys are already strings" do
    spec = %{
      "root" => "page",
      "elements" => %{
        :page => %{
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

    assert {:ok, normalized} = Normalize.canonical(spec)

    assert normalized["elements"]["page"] == %{
             "type" => "row",
             "props" => %{"gap" => "md"},
             "children" => ["metric_1"]
           }

    assert normalized["elements"]["metric_1"] == %{
             "type" => "metric",
             "props" => %{"label" => "Revenue", "value" => "$100"},
             "children" => []
           }
  end

  test "canonical/1 decodes JSON strings before normalizing" do
    spec = %{
      "root" => "page",
      "elements" => %{
        "page" => %{
          "type" => "row",
          "props" => %{},
          "children" => ["metric_1"]
        },
        "metric_1" => %{
          "type" => "metric",
          "props" => %{"label" => "Revenue", "value" => "$100"},
          "children" => []
        }
      }
    }

    assert {:ok, normalized} = spec |> Jason.encode!() |> Normalize.canonical()
    assert normalized == spec
  end

  test "canonical/1 rejects valid non-object JSON input" do
    assert {:error, [{:invalid_spec, _message}]} = Normalize.canonical("[]")
  end

  test "canonical/1 rejects quoted top-level JSON strings" do
    assert {:error, [{:invalid_spec, _message}]} = Normalize.canonical(~S("\"{}\""))
  end

  test "canonical/1 preserves an explicit false root value" do
    spec = %{root: false, elements: %{}}

    assert {:ok, normalized} = Normalize.canonical(spec)
    assert normalized["root"] == "false"
  end

  test "canonical/1 preserves malformed child shapes for downstream validation errors" do
    spec = %{
      root: :page,
      elements: %{
        :page => %{
          type: :row,
          props: %{},
          children: %{unexpected: true}
        }
      }
    }

    assert {:ok, normalized} = Normalize.canonical(spec)
    assert {:error, reasons} = Spec.validate(normalized, Catalog)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :invalid_children_type end)
  end

  test "for_validation/1 canonicalizes mixed nested keys even when top-level keys are already strings" do
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

    assert {:ok, normalized} = Normalize.for_validation(spec)

    assert normalized == %{
             "root" => "metric_1",
             "elements" => %{
               "metric_1" => %{
                 "type" => "metric",
                 "props" => %{"{:bad, :key}" => true},
                 "children" => []
               }
             }
           }
  end
end
