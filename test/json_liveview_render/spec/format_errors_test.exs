defmodule JsonLiveviewRender.Spec.FormatErrorsTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Spec.Errors
  alias JsonLiveviewRenderTest.Fixtures.Catalog

  describe "format_errors/1" do
    test "formats a single error" do
      errors = [Errors.root_missing()]
      result = Spec.format_errors(errors)

      assert result =~ "The generated UI spec has the following errors:"
      assert result =~ "- spec must include a root key"
    end

    test "formats multiple errors" do
      errors = [
        Errors.unknown_component("card_1", "Cardx"),
        Errors.missing_required_prop("metric_1", "value")
      ]

      result = Spec.format_errors(errors)

      assert result =~ ~s(element "card_1" references unknown component "Cardx")
      assert result =~ ~s(element "metric_1" missing required prop "value")
    end

    test "handles empty error list" do
      result = Spec.format_errors([])
      assert result == "The generated UI spec has the following errors:\n"
    end
  end

  describe "format_errors/2 with catalog" do
    test "enriches unknown_component errors with available types" do
      errors = [Errors.unknown_component("card_1", "Cardx")]
      result = Spec.format_errors(errors, Catalog)

      assert result =~ "available types:"
      assert result =~ "metric"
      assert result =~ "data_table"
    end

    test "non-unknown_component errors are unchanged with catalog" do
      errors = [Errors.missing_required_prop("metric_1", "value")]
      result = Spec.format_errors(errors, Catalog)

      assert result =~ ~s(element "metric_1" missing required prop "value")
      refute result =~ "available types:"
    end

    test "mixed error types format correctly" do
      errors = [
        Errors.unknown_component("card_1", "Cardx"),
        Errors.missing_required_prop("metric_1", "value"),
        Errors.cycle_detected(["a", "b", "a"])
      ]

      result = Spec.format_errors(errors, Catalog)

      lines = String.split(result, "\n")
      assert length(lines) == 4
      assert Enum.at(lines, 1) =~ "available types:"
      assert Enum.at(lines, 2) =~ "missing required prop"
      assert Enum.at(lines, 3) =~ "cycle detected"
    end
  end
end
