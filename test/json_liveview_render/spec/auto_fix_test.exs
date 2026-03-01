defmodule JsonLiveviewRender.Spec.AutoFixTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  defmodule NumericCatalog do
    use JsonLiveviewRender.Catalog

    component :gauge do
      description("Gauge with numeric props")
      prop(:label, :string, required: true)
      prop(:count, :integer, required: true)
      prop(:ratio, :float)
      prop(:enabled, :boolean)
    end
  end

  @clean_spec %{
    "root" => "metric_1",
    "elements" => %{
      "metric_1" => %{
        "type" => "metric",
        "props" => %{"label" => "Revenue", "value" => "$100"},
        "children" => []
      }
    }
  }

  describe "prop type coercion" do
    test "coerces string to integer" do
      spec = %{
        "root" => "g_1",
        "elements" => %{
          "g_1" => %{
            "type" => "gauge",
            "props" => %{"label" => "Hits", "count" => "42"},
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} = Spec.auto_fix(spec, NumericCatalog)

      assert fixed["elements"]["g_1"]["props"]["count"] == 42
      assert Enum.any?(fixes, &String.contains?(&1, "coerced"))
      assert Enum.any?(fixes, &String.contains?(&1, "integer"))
    end

    test "does not coerce string with trailing characters to integer" do
      spec = %{
        "root" => "g_1",
        "elements" => %{
          "g_1" => %{
            "type" => "gauge",
            "props" => %{"label" => "Hits", "count" => "42px"},
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} = Spec.auto_fix(spec, NumericCatalog)

      assert fixed["elements"]["g_1"]["props"]["count"] == "42px"
      refute Enum.any?(fixes, &String.contains?(&1, "count"))
    end

    test "coerces string to float" do
      spec = %{
        "root" => "g_1",
        "elements" => %{
          "g_1" => %{
            "type" => "gauge",
            "props" => %{"label" => "Ratio", "count" => 1, "ratio" => "3.14"},
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} = Spec.auto_fix(spec, NumericCatalog)

      assert fixed["elements"]["g_1"]["props"]["ratio"] == 3.14
      assert Enum.any?(fixes, &String.contains?(&1, "float"))
    end

    test "coerces string 'true' to boolean true" do
      # We need a catalog with a boolean prop to test this properly.
      # The fixture Catalog doesn't have boolean props on the main test components.
      # Use SchemaFixtures.MediumCatalog which has :show_totals boolean on data_table.
      spec = %{
        "root" => "dt_1",
        "elements" => %{
          "dt_1" => %{
            "type" => "data_table",
            "props" => %{
              "columns" => ["id"],
              "rows_binding" => "rows",
              "show_totals" => "true"
            },
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} =
        Spec.auto_fix(spec, JsonLiveviewRenderTest.SchemaFixtures.MediumCatalog)

      assert fixed["elements"]["dt_1"]["props"]["show_totals"] == true
      assert Enum.any?(fixes, &String.contains?(&1, "coerced"))
      assert Enum.any?(fixes, &String.contains?(&1, "boolean"))
    end

    test "coerces string 'false' to boolean false" do
      spec = %{
        "root" => "dt_1",
        "elements" => %{
          "dt_1" => %{
            "type" => "data_table",
            "props" => %{
              "columns" => ["id"],
              "rows_binding" => "rows",
              "show_totals" => "false"
            },
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} =
        Spec.auto_fix(spec, JsonLiveviewRenderTest.SchemaFixtures.MediumCatalog)

      assert fixed["elements"]["dt_1"]["props"]["show_totals"] == false
      assert Enum.any?(fixes, &String.contains?(&1, "coerced"))
    end

    test "does not coerce non-parseable strings" do
      spec = %{
        "root" => "dt_1",
        "elements" => %{
          "dt_1" => %{
            "type" => "data_table",
            "props" => %{
              "columns" => ["id"],
              "rows_binding" => "rows",
              "show_totals" => "maybe"
            },
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} =
        Spec.auto_fix(spec, JsonLiveviewRenderTest.SchemaFixtures.MediumCatalog)

      assert fixed["elements"]["dt_1"]["props"]["show_totals"] == "maybe"
      refute Enum.any?(fixes, &String.contains?(&1, "coerced"))
    end
  end

  describe "children normalization" do
    test "wraps single string child into list" do
      spec = %{
        "root" => "page",
        "elements" => %{
          "page" => %{
            "type" => "column",
            "props" => %{},
            "children" => "metric_1"
          },
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} = Spec.auto_fix(spec, Catalog)

      assert fixed["elements"]["page"]["children"] == ["metric_1"]
      assert Enum.any?(fixes, &String.contains?(&1, "wrapped single child"))
    end

    test "drops non-string-coercible children (e.g. nested maps/tuples) instead of crashing" do
      spec = %{
        "root" => "page",
        "elements" => %{
          "page" => %{
            "type" => "column",
            "props" => %{},
            "children" => ["metric_1", %{"nested" => "object"}, {:bad, "child"}, "metric_2"]
          },
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          },
          "metric_2" => %{
            "type" => "metric",
            "props" => %{"label" => "Cost", "value" => "$2"},
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} = Spec.auto_fix(spec, Catalog)

      assert fixed["elements"]["page"]["children"] == ["metric_1", "metric_2"]
      assert Enum.count(fixes, &String.contains?(&1, "dropped non-string child")) == 2
    end
  end

  describe "orphan detection" do
    test "detects unreachable elements" do
      spec = %{
        "root" => "metric_1",
        "elements" => %{
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          },
          "orphan_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Ghost", "value" => "0"},
            "children" => []
          }
        }
      }

      {:ok, _fixed, fixes} = Spec.auto_fix(spec, Catalog)

      assert Enum.any?(fixes, &String.starts_with?(&1, "warning:"))
      assert Enum.any?(fixes, &String.contains?(&1, "orphan_1"))
    end

    test "no orphan warnings when all elements are reachable" do
      {:ok, _fixed, fixes} = Spec.auto_fix(@clean_spec, Catalog)

      refute Enum.any?(fixes, &String.starts_with?(&1, "warning:"))
    end
  end

  describe "no-op and idempotency" do
    test "clean spec returns no fixes" do
      {:ok, fixed, fixes} = Spec.auto_fix(@clean_spec, Catalog)

      assert fixes == []
      assert fixed["root"] == "metric_1"
      assert fixed["elements"]["metric_1"]["type"] == "metric"
    end

    test "auto_fix is idempotent" do
      spec = %{
        "root" => "page",
        "elements" => %{
          "page" => %{
            "type" => "column",
            "props" => %{},
            "children" => "metric_1"
          },
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          }
        }
      }

      {:ok, fixed1, fixes1} = Spec.auto_fix(spec, Catalog)
      {:ok, fixed2, fixes2} = Spec.auto_fix(fixed1, Catalog)

      assert fixed1 == fixed2
      assert fixes2 == []
      assert length(fixes1) > 0
    end
  end

  describe "error cases" do
    test "returns error when elements is missing" do
      assert {:error, :elements_missing} = Spec.auto_fix(%{"root" => "x"}, Catalog)
    end

    test "handles non-String.Chars prop keys without crashing" do
      spec = %{
        "root" => "m_1",
        "elements" => %{
          "m_1" => %{
            "type" => "metric",
            "props" => %{%{"nested" => "key"} => "value", "label" => "Rev", "value" => "$1"},
            "children" => []
          }
        }
      }

      {:ok, fixed, _fixes} = Spec.auto_fix(spec, Catalog)

      # The non-string key is stringified via inspect fallback
      assert is_map(fixed["elements"]["m_1"]["props"])
    end

    test "handles non-stringable element ids without crashing" do
      malformed_id = %{"nested" => "id"}

      spec = %{
        "root" => "metric_1",
        "elements" => %{
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          },
          malformed_id => %{
            "type" => "metric",
            "props" => %{"label" => "Ghost", "value" => "0"},
            "children" => []
          }
        }
      }

      {:ok, fixed, _fixes} = Spec.auto_fix(spec, Catalog)

      assert Map.has_key?(fixed["elements"], inspect(malformed_id))
    end

    test "handles malformed non-map root element during orphan traversal" do
      spec = %{
        "root" => "bad_root",
        "elements" => %{
          "bad_root" => 123,
          "orphan_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Ghost", "value" => "0"},
            "children" => []
          }
        }
      }

      {:ok, fixed, fixes} = Spec.auto_fix(spec, Catalog)

      assert fixed["elements"]["bad_root"] == 123
      assert Enum.any?(fixes, &String.contains?(&1, ~s("orphan_1")))
    end
  end

  describe "integration with validate" do
    test "auto_fix output passes validation" do
      spec = %{
        "root" => "page",
        "elements" => %{
          "page" => %{
            "type" => "column",
            "props" => %{},
            "children" => "metric_1"
          },
          "metric_1" => %{
            "type" => "metric",
            "props" => %{"label" => "Rev", "value" => "$1"},
            "children" => []
          }
        }
      }

      {:ok, fixed, _fixes} = Spec.auto_fix(spec, Catalog)
      assert {:ok, _validated} = Spec.validate(fixed, Catalog)
    end
  end
end
