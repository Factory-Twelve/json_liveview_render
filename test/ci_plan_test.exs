defmodule CiPlanTest do
  use ExUnit.Case, async: true

  @plan_path Path.expand("../scripts/ci_plan.md", __DIR__)
  @script_path Path.expand("../scripts/ci_local.sh", __DIR__)
  @workflow_path Path.expand("../.github/workflows/ci.yml", __DIR__)
  @workflow_text File.read!(@workflow_path)
  @readme_path Path.expand("../README.md", __DIR__)

  test "local script and workflow stay aligned with CI plan command names" do
    plan = read_ci_plan()

    {script_output, 0} =
      System.cmd(@script_path, ["--dry-run", "--matrix", "1.15,1.19"], stderr_to_stdout: true)

    Enum.each(plan.commands, fn {check, command} ->
      assert script_output =~ check
      assert script_output =~ command
      assert @workflow_text =~ command
    end)

    Enum.each(plan.versions, fn version ->
      assert @workflow_text =~ "matrix_label: \"#{version}\""
    end)
  end

  test "format check is intentionally only on the 1.19 matrix slot" do
    plan = read_ci_plan()

    assert Map.fetch!(plan.matrix, "1.15") == ["deps", "compile", "test"]
    refute "format" in Map.fetch!(plan.matrix, "1.15")
    assert "format" in Map.fetch!(plan.matrix, "1.19")
  end

  test "workflow matrix matches plan definitions" do
    plan = read_ci_plan()
    workflow_matrix = parse_workflow_matrix(@workflow_text)

    assert MapSet.new(plan.versions) == MapSet.new(Map.keys(workflow_matrix))

    Enum.each(plan.matrix_entries, fn {version, matrix} ->
      workflow_entry = Map.fetch!(workflow_matrix, version)

      assert workflow_entry.elixir == matrix.elixir
      assert workflow_entry.otp == matrix.otp
      assert workflow_entry.run_format == "format" in matrix.checks
    end)
  end

  test "readme documents the matrix split policy" do
    readme = File.read!(@readme_path)

    assert readme =~ "For iterative local work, run only the cheapest parity slot"
    assert readme =~ "Format is intentionally single-slot (`1.19`) to keep iterative runs faster."
    assert readme =~ "--matrix 1.15,1.19"
  end

  defp read_ci_plan do
    text = File.read!(@plan_path)
    matrix_entries = parse_matrix_entries(text)

    %{
      commands: parse_commands(text),
      matrix: parse_matrix_entries_to_checks(matrix_entries),
      matrix_entries: matrix_entries,
      versions: parse_versions(matrix_entries)
    }
  end

  defp parse_commands(text) do
    {_section, lines} = extract_section(text, "## Commands")

    lines
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      trimmed = String.trim(line)

      if String.starts_with?(trimmed, "-") do
        entry = String.trim_leading(trimmed, "-")
        [name, command] = String.split(String.trim_leading(entry, " "), ": ", parts: 2)
        Map.put(acc, name, command)
      else
        acc
      end
    end)
  end

  defp parse_matrix_entries(text) do
    {_section, lines} = extract_section(text, "## Matrix")

    String.split(lines, "\n", trim: true)
    |> Enum.reduce(%{}, fn line, acc ->
      trimmed = String.trim(line)

      cond do
        trimmed == "" ->
          acc

        String.starts_with?(trimmed, "#") ->
          acc

        true ->
          parts = String.split(trimmed, "|", trim: true)

          case parts do
            [version, elixir, otp, checks] ->
              checks_list = String.split(checks, ",", trim: true)
              Map.put(acc, version, %{elixir: elixir, otp: otp, checks: checks_list})

            _ ->
              acc
          end
      end
    end)
  end

  defp parse_matrix_entries_to_checks(matrix_entries) do
    matrix_entries
    |> Enum.reduce(%{}, fn {version, matrix}, acc ->
      Map.put(acc, version, matrix.checks)
    end)
  end

  defp parse_versions(matrix_entries) do
    matrix_entries
    |> Map.keys()
    |> Enum.sort()
  end

  defp parse_workflow_matrix(text) do
    Regex.scan(
      ~r/^\s*-\s+elixir:\s+"([^"]+)"\s*\n^\s*otp:\s+"([^"]+)"\s*\n^\s*matrix_label:\s+"([^"]+)"\s*\n^\s*run_format:\s+(true|false)/m,
      text,
      capture: :all_but_first
    )
    |> Enum.reduce(%{}, fn [elixir, otp, version, run_format], acc ->
      Map.put(acc, version, %{elixir: elixir, otp: otp, run_format: run_format == "true"})
    end)
  end

  defp extract_section(text, heading) do
    pattern = ~r/^#{Regex.escape(heading)}\n(.*?)(?:\n^## |\z)/ms

    case Regex.run(pattern, text) do
      [_, section] ->
        {heading, section}

      nil ->
        {heading, ""}
    end
  end
end
