defmodule JsonLiveviewRender.Benchmark.Guardrail do
  @moduledoc false

  @type threshold_suite :: %{
          required(:metric) => String.t(),
          required(:max_regression_percent) => float(),
          required(:cases) => %{required(String.t()) => number()}
        }

  @type thresholds :: %{
          required(:path) => String.t(),
          required(:version) => pos_integer(),
          required(:suites) => %{required(String.t()) => threshold_suite()}
        }

  @type evaluation_result :: %{
          required(:status) => :pass | :fail,
          required(:threshold_file) => String.t(),
          required(:threshold_version) => pos_integer(),
          required(:checked_count) => non_neg_integer(),
          required(:skipped_count) => non_neg_integer(),
          required(:failure_count) => non_neg_integer(),
          required(:failures) => [map()],
          required(:skipped) => [map()]
        }

  @spec default_thresholds_path() :: String.t()
  def default_thresholds_path do
    Path.expand("../../../benchmarks/thresholds.json", __DIR__)
  end

  @spec load_thresholds(String.t()) :: thresholds()
  def load_thresholds(path \\ default_thresholds_path()) when is_binary(path) do
    expanded_path = Path.expand(path)

    decoded =
      expanded_path
      |> File.read!()
      |> Jason.decode!()

    normalize_thresholds!(decoded, expanded_path)
  rescue
    exception in [File.Error, Jason.DecodeError, KeyError, MatchError, ArgumentError] ->
      raise ArgumentError,
            "invalid benchmark guardrail thresholds at #{Path.expand(path)}: #{Exception.message(exception)}"
  end

  @spec evaluate([map()], thresholds()) :: evaluation_result()
  def evaluate(reports, thresholds) when is_list(reports) and is_map(thresholds) do
    {failures, skipped, checked_count} =
      Enum.reduce(reports, {[], [], 0}, fn report, {failures_acc, skipped_acc, checked_acc} ->
        case_name = report_case_name(report)

        Enum.reduce(
          Map.get(report, :suites, []),
          {failures_acc, skipped_acc, checked_acc},
          fn suite, {suite_failures, suite_skipped, suite_checked} ->
            suite_name = Map.get(suite, :name)

            evaluate_suite(
              suite,
              suite_name,
              case_name,
              thresholds,
              suite_failures,
              suite_skipped,
              suite_checked
            )
          end
        )
      end)

    %{
      status: if(failures == [], do: :pass, else: :fail),
      threshold_file: thresholds.path,
      threshold_version: thresholds.version,
      checked_count: checked_count,
      skipped_count: length(skipped),
      failure_count: length(failures),
      failures: Enum.reverse(failures),
      skipped: Enum.reverse(skipped)
    }
  end

  @spec render_text(evaluation_result()) :: iodata()
  def render_text(result) do
    failure_lines =
      Enum.map(result.failures, fn failure ->
        [
          "  failure suite=",
          failure.suite,
          " case=",
          failure.case_name,
          " metric=",
          failure.metric,
          " baseline=",
          number_to_string(failure.baseline),
          " actual=",
          number_to_string(failure.actual),
          " allowed_max=",
          number_to_string(failure.allowed_max),
          " regression_percent=",
          number_to_string(failure.regression_percent),
          "\n"
        ]
      end)

    skipped_lines =
      Enum.map(result.skipped, fn skipped ->
        [
          "  skipped suite=",
          skipped.suite,
          " case=",
          skipped.case_name,
          " reason=",
          skipped.reason,
          "\n"
        ]
      end)

    [
      "Guardrail:\n",
      "  status=",
      Atom.to_string(result.status),
      "\n",
      "  threshold_file=",
      result.threshold_file,
      "\n",
      "  threshold_version=",
      Integer.to_string(result.threshold_version),
      "\n",
      "  checked=",
      Integer.to_string(result.checked_count),
      "\n",
      "  skipped=",
      Integer.to_string(result.skipped_count),
      "\n",
      "  failures=",
      Integer.to_string(result.failure_count),
      "\n",
      failure_lines,
      skipped_lines
    ]
  end

  defp normalize_thresholds!(decoded, path) when is_map(decoded) do
    version = Map.fetch!(decoded, "version")
    validate_version!(version)

    suites =
      decoded
      |> Map.fetch!("suites")
      |> normalize_suites!()

    %{
      path: path,
      version: version,
      suites: suites
    }
  end

  defp normalize_thresholds!(decoded, _path) do
    raise ArgumentError,
          "expected threshold file to be a JSON object, got: #{inspect(decoded)}"
  end

  defp validate_version!(version) when is_integer(version) and version > 0, do: :ok

  defp validate_version!(version) do
    raise ArgumentError, "expected version to be a positive integer, got: #{inspect(version)}"
  end

  defp normalize_suites!(suites) when is_map(suites) and map_size(suites) > 0 do
    Enum.reduce(suites, %{}, fn {suite_name, suite_config}, acc ->
      normalized_suite = normalize_suite!(suite_name, suite_config)
      Map.put(acc, suite_name, normalized_suite)
    end)
  end

  defp normalize_suites!(suites) do
    raise ArgumentError, "expected suites to be a non-empty map, got: #{inspect(suites)}"
  end

  defp normalize_suite!(suite_name, suite_config)
       when is_binary(suite_name) and is_map(suite_config) do
    metric = Map.fetch!(suite_config, "metric")
    validate_metric!(suite_name, metric)

    max_regression_percent =
      suite_config
      |> Map.fetch!("max_regression_percent")
      |> normalize_number!("#{suite_name}.max_regression_percent")

    if max_regression_percent < 0 do
      raise ArgumentError,
            "expected #{suite_name}.max_regression_percent to be >= 0, got: #{inspect(max_regression_percent)}"
    end

    %{
      metric: metric,
      max_regression_percent: max_regression_percent,
      cases: normalize_cases!(suite_name, Map.fetch!(suite_config, "cases"))
    }
  end

  defp normalize_suite!(suite_name, suite_config) do
    raise ArgumentError,
          "expected suite #{inspect(suite_name)} to be a map, got: #{inspect(suite_config)}"
  end

  defp validate_metric!(_suite_name, metric) when is_binary(metric) and metric != "", do: :ok

  defp validate_metric!(suite_name, metric) do
    raise ArgumentError,
          "expected #{suite_name}.metric to be a non-empty string, got: #{inspect(metric)}"
  end

  defp normalize_cases!(suite_name, cases) when is_map(cases) and map_size(cases) > 0 do
    Enum.reduce(cases, %{}, fn {case_name, baseline}, acc ->
      normalized_baseline = normalize_number!(baseline, "#{suite_name}.cases.#{case_name}")

      if normalized_baseline <= 0 do
        raise ArgumentError,
              "expected #{suite_name}.cases.#{case_name} baseline > 0, got: #{inspect(normalized_baseline)}"
      end

      Map.put(acc, case_name, normalized_baseline)
    end)
  end

  defp normalize_cases!(suite_name, cases) do
    raise ArgumentError,
          "expected #{suite_name}.cases to be a non-empty map, got: #{inspect(cases)}"
  end

  defp normalize_number!(value, _path) when is_integer(value), do: value * 1.0
  defp normalize_number!(value, _path) when is_float(value), do: value

  defp normalize_number!(value, path) do
    raise ArgumentError, "expected #{path} to be numeric, got: #{inspect(value)}"
  end

  defp evaluate_suite(
         suite,
         suite_name,
         case_name,
         thresholds,
         failures_acc,
         skipped_acc,
         checked_acc
       ) do
    case Map.fetch(thresholds.suites, suite_name) do
      :error ->
        skipped = %{suite: suite_name, case_name: case_name, reason: "missing_suite_threshold"}
        {failures_acc, [skipped | skipped_acc], checked_acc}

      {:ok, suite_threshold} ->
        evaluate_suite_case(
          suite,
          suite_name,
          case_name,
          suite_threshold,
          failures_acc,
          skipped_acc,
          checked_acc
        )
    end
  end

  defp evaluate_suite_case(
         suite,
         suite_name,
         case_name,
         suite_threshold,
         failures_acc,
         skipped_acc,
         checked_acc
       ) do
    case Map.fetch(suite_threshold.cases, case_name) do
      :error ->
        skipped = %{suite: suite_name, case_name: case_name, reason: "missing_case_threshold"}
        {failures_acc, [skipped | skipped_acc], checked_acc}

      {:ok, baseline} ->
        evaluate_metric(
          suite,
          suite_name,
          case_name,
          suite_threshold.metric,
          suite_threshold.max_regression_percent,
          baseline,
          failures_acc,
          skipped_acc,
          checked_acc
        )
    end
  end

  defp evaluate_metric(
         suite,
         suite_name,
         case_name,
         metric,
         max_regression_percent,
         baseline,
         failures_acc,
         skipped_acc,
         checked_acc
       ) do
    metrics = Map.get(suite, :metrics, %{})

    case metric_value(metrics, metric) do
      nil ->
        skipped = %{suite: suite_name, case_name: case_name, reason: "missing_metric_#{metric}"}
        {failures_acc, [skipped | skipped_acc], checked_acc}

      actual ->
        allowed_max = baseline * (1.0 + max_regression_percent / 100.0)
        checked_count = checked_acc + 1
        regression_percent = (actual - baseline) / baseline * 100.0

        if actual > allowed_max do
          failure = %{
            suite: suite_name,
            case_name: case_name,
            metric: metric,
            baseline: round_number(baseline),
            actual: round_number(actual),
            allowed_max: round_number(allowed_max),
            max_regression_percent: round_number(max_regression_percent),
            regression_percent: round_number(regression_percent)
          }

          {[failure | failures_acc], skipped_acc, checked_count}
        else
          {failures_acc, skipped_acc, checked_count}
        end
    end
  end

  defp metric_value(metrics, metric_name) when is_map(metrics) and is_binary(metric_name) do
    Enum.find_value(metrics, fn {key, value} ->
      if to_string(key) == metric_name and is_number(value) do
        value * 1.0
      end
    end)
  end

  defp metric_value(_metrics, _metric_name), do: nil

  defp report_case_name(report) do
    report
    |> Map.get(:config, %{})
    |> Map.get(:case_name)
    |> case do
      nil -> "default"
      case_name -> to_string(case_name)
    end
  end

  defp round_number(value) when is_number(value) do
    value
    |> Float.round(3)
  end

  defp number_to_string(value) when is_integer(value), do: Integer.to_string(value)

  defp number_to_string(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 3)

  defp number_to_string(value), do: to_string(value)
end
