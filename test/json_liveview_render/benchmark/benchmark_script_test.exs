defmodule JsonLiveviewRender.Benchmark.BenchmarkScriptTest do
  use ExUnit.Case, async: false

  @mix_args_file "bench_script_args.txt"

  defp with_stub_mix(fun) do
    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "json_liveview_render_benchmark_script_#{System.unique_integer([:positive])}"
      )

    root = Path.expand("../../..", __DIR__)
    script_path = Path.join(root, "scripts/benchmark.sh")
    args_path = Path.join(tmp_dir, @mix_args_file)
    mix_path = Path.join(tmp_dir, "mix")

    File.mkdir_p!(tmp_dir)

    File.write!(mix_path, """
    #!/usr/bin/env bash
    printf '%s\\n' "$@" > "#{args_path}"
    """)

    File.chmod!(mix_path, 0o755)

    try do
      fun.(script_path, args_path, tmp_dir)
    after
      File.rm_rf!(tmp_dir)
    end
  end

  test "enforces json output in CI regardless of user format flags" do
    with_stub_mix(fn script_path, args_path, tmp_dir ->
      env = [{"CI", "true"}, {"PATH", "#{tmp_dir}:#{System.get_env("PATH", "")}"}]

      System.cmd("bash", [script_path, "--iterations", "10", "--format", "text"], env: env)

      args = File.read!(args_path) |> String.split(~r/\r?\n/, trim: true)
      assert args == ["json_liveview_render.bench", "--iterations", "10", "--format", "json"]
    end)
  end

  test "does not force json format outside CI" do
    with_stub_mix(fn script_path, args_path, tmp_dir ->
      env = [{"CI", "false"}, {"PATH", "#{tmp_dir}:#{System.get_env("PATH", "")}"}]

      System.cmd("bash", [script_path, "--format", "text"], env: env)

      args = File.read!(args_path) |> String.split(~r/\r?\n/, trim: true)
      assert args == ["json_liveview_render.bench", "--format", "text"]
    end)
  end
end
