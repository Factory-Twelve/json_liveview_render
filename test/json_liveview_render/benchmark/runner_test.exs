defmodule JsonLiveviewRender.Benchmark.RunnerTest do
  use ExUnit.Case, async: false

  alias JsonLiveviewRender.Benchmark.Runner

  test "render_text handles unknown logical processor count" do
    report = %{
      config: %{
        iterations: 3,
        suites: ["validate"],
        seed: 123,
        node_count: 25,
        depth: 3,
        branching_factor: 2,
        format: :text,
        ci: false
      },
      metadata: %{
        benchmarked_at_utc: "2026-03-01T00:00:00Z",
        project: %{
          app: :json_liveview_render,
          version: "0.3.0-dev",
          elixir: "1.17.0",
          otp_release: "26"
        },
        machine: %{
          os_type: "beos/unix",
          logical_processors: :unknown,
          schedulers_online: 8,
          word_size: 64
        }
      },
      suites: [
        %{
          name: "validate",
          metrics: %{
            iterations: 3,
            total_microseconds: 1000,
            mean_microseconds: 333.3,
            min_microseconds: 250,
            max_microseconds: 450,
            p95_microseconds: 420,
            p99_microseconds: 440
          }
        }
      ]
    }

    output = Runner.render_text(report) |> IO.iodata_to_binary()

    assert output =~ "logical_processors=unknown"
    assert output =~ "suite=validate"
  end
end
