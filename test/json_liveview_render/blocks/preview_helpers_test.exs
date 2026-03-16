defmodule JsonLiveviewRender.Blocks.PreviewHelpersTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  test "returns the default for nested values that are not string-compatible" do
    assert PreviewHelpers.string(%{"label" => %{"nested" => "value"}}, :label) == nil
    assert PreviewHelpers.string(%{label: ["unexpected"]}, :label, "fallback") == "fallback"
  end

  test "preserves numeric and boolean defaults for nested values" do
    assert PreviewHelpers.number(%{"confidence" => 0.78}, :confidence) == 0.78
    assert PreviewHelpers.number(%{"confidence" => "high"}, :confidence, 0.0) == 0.0
    assert PreviewHelpers.boolean(%{blocking: true}, :blocking) == true
    assert PreviewHelpers.boolean(%{"blocking" => "yes"}, :blocking, false) == false
  end
end
