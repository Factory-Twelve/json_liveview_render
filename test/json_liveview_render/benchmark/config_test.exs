defmodule JsonLiveviewRender.Benchmark.ConfigTest do
  use ExUnit.Case, async: false

  alias JsonLiveviewRender.Benchmark.Config

  describe "normalize suites" do
    test "rejects empty suite list" do
      assert_raise ArgumentError, ~r/expected at least one suite/, fn ->
        Config.from_options(suites: "")
      end
    end

    test "rejects empty suite array" do
      assert_raise ArgumentError, ~r/expected at least one suite/, fn ->
        Config.from_options(suites: [])
      end
    end
  end
end
