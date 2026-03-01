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

    test "rejects whitespace-only suite list" do
      assert_raise ArgumentError, ~r/expected at least one suite/, fn ->
        Config.from_options(suites: "   ,   ")
      end
    end

    test "supports deterministic node shape configuration" do
      config = Config.from_options(seed: 17, node_count: 25, depth: 5, branching_factor: 3)

      assert config.seed == 17
      assert config.node_count == 25
      assert config.depth == 5
      assert config.branching_factor == 3
    end

    test "maps legacy shape options into node_count" do
      config = Config.from_options(seed: 17, sections: 3, columns: 2, metrics_per_column: 4)

      assert config.node_count == 1 + 3 * (1 + 2 * (1 + 4))
    end

    test "validates shape against configured branching/depth capacity" do
      assert_raise ArgumentError,
                   ~r/node_count 50 exceeds max nodes/,
                   fn ->
                     Config.from_options(node_count: 50, depth: 2, branching_factor: 2)
                   end
    end
  end
end
