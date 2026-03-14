defmodule JsonLiveviewRender.Blocks.PreviewHelpersTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  test "returns the default for nested values that are not string-compatible" do
    assert PreviewHelpers.string(%{"label" => %{"nested" => "value"}}, :label) == nil
    assert PreviewHelpers.string(%{label: ["unexpected"]}, :label, "fallback") == "fallback"
  end
end
