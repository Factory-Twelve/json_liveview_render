defmodule JsonLiveviewRender.ReadmeTest do
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../README.md", __DIR__)

  test "devtools README snippet uses config-only dev_tools_enabled guard" do
    readme = File.read!(@readme_path)

    dev_tools_section =
      readme
      |> String.split("## DevTools (Experimental)", parts: 2)
      |> List.last()
      |> String.split("Recommended pattern:", parts: 2)
      |> List.first()

    assert dev_tools_section =~
             "dev_tools_enabled={Application.get_env(:json_liveview_render, :dev_tools_enabled, false)}"

    refute dev_tools_section =~ "Mix.env() == :dev"
    refute dev_tools_section =~ "Mix.env()"
  end

  test "benchmark README snippet uses parseable seed format" do
    readme = File.read!(@readme_path)

    benchmark_section =
      readme
      |> String.split("## Benchmark Harness", parts: 2)
      |> List.last()
      |> String.split("## Learnings", parts: 2)
      |> List.first()

    assert benchmark_section =~ "--seed 20260301"
    refute benchmark_section =~ "--seed 2026_03_01"
  end
end
