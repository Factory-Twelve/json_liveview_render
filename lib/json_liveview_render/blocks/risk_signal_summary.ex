defmodule JsonLiveviewRender.Blocks.RiskSignalSummary do
  @moduledoc """
  Internal experimental risk signal summary renderer for reusable depth review
  panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:signal_id, :string, required: true)
  attr(:signal_key, :string, required: true)
  attr(:signal_type, :string, required: true)
  attr(:status, :string, required: true)
  attr(:severity, :string, required: true)
  attr(:summary, :string, required: true)
  attr(:observed_at, :string, required: true)
  attr(:effective_window, :map, default: %{})
  attr(:source, :map, default: %{})
  attr(:facts, :list, default: [])
  attr(:subject_impacts, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:normalized_window, normalize_window(assigns.effective_window))
      |> Map.put(:normalized_source, normalize_source(assigns.source))
      |> Map.put(:normalized_facts, normalize_facts(assigns.facts))
      |> Map.put(:normalized_impacts, normalize_impacts(assigns.subject_impacts))

    ~H"""
    <article
      class="genui-risk-signal-summary"
      data-signal-id={@signal_id}
      data-status={@status}
      data-severity={@severity}
      data-signal-type={@signal_type}
    >
      <header class="genui-risk-signal-summary__header">
        <span class="genui-risk-signal-summary__severity"><%= @severity %></span>
        <h4>Risk signal</h4>
        <span class="genui-risk-signal-summary__type"><%= @signal_type %></span>
      </header>
      <p class="genui-risk-signal-summary__key"><%= @signal_key %></p>
      <p class="genui-risk-signal-summary__summary"><%= @summary %></p>
      <dl class="genui-risk-signal-summary__meta">
        <div>
          <dt>Status</dt>
          <dd><%= @status %></dd>
        </div>
        <div>
          <dt>Observed</dt>
          <dd><%= @observed_at %></dd>
        </div>
        <div :if={@normalized_window}>
          <dt>Window</dt>
          <dd><%= format_window(@normalized_window) %></dd>
        </div>
        <div :if={@normalized_source}>
          <dt>Source</dt>
          <dd><%= format_source(@normalized_source) %></dd>
        </div>
        <div :if={@normalized_source}>
          <dt>Reference</dt>
          <dd><%= @normalized_source.reference %></dd>
        </div>
      </dl>
      <section :if={@normalized_facts != []} class="genui-risk-signal-summary__facts">
        <h5>Facts</h5>
        <ul>
          <li :for={fact <- @normalized_facts} data-fact-key={fact.fact_key}>
            <span><%= fact.fact_key %></span>
            <strong><%= format_fact_value(fact) %></strong>
          </li>
        </ul>
      </section>
      <section :if={@normalized_impacts != []} class="genui-risk-signal-summary__impacts">
        <h5>Subject impacts</h5>
        <ul>
          <li
            :for={impact <- @normalized_impacts}
            class="genui-risk-signal-summary__impact"
            data-subject-id={impact.subject_id}
            data-impact-type={impact.impact_type}
            data-severity={impact.severity}
          >
            <div class="genui-risk-signal-summary__impact-header">
              <strong><%= impact.subject_id %></strong>
              <span><%= impact.impact_type %></span>
              <span><%= impact.severity %></span>
            </div>
            <p :if={impact.subject_kind} class="genui-risk-signal-summary__impact-kind">
              <%= impact.subject_kind %>
            </p>
            <p class="genui-risk-signal-summary__impact-summary"><%= impact.summary %></p>
          </li>
        </ul>
      </section>
      <div :if={@children != []} class="genui-risk-signal-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_window(window) when is_map(window) do
    start_at = PreviewHelpers.string(window, :start_at)
    end_at = PreviewHelpers.string(window, :end_at)

    if is_binary(start_at) and start_at != "" do
      %{start_at: start_at, end_at: end_at}
    end
  end

  defp normalize_window(_window), do: nil

  defp normalize_source(source) when is_map(source) do
    source_kind = PreviewHelpers.string(source, :source_kind)
    source_name = PreviewHelpers.string(source, :source_name)
    reference = PreviewHelpers.string(source, :reference)

    if filled?(source_kind) and filled?(source_name) and filled?(reference) do
      %{source_kind: source_kind, source_name: source_name, reference: reference}
    end
  end

  defp normalize_source(_source), do: nil

  defp normalize_facts(facts) do
    facts
    |> Enum.map(&normalize_fact/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_fact(fact) when is_map(fact) do
    fact_key = PreviewHelpers.string(fact, :fact_key)
    value = PreviewHelpers.value(fact, :value)

    if filled?(fact_key) and scalar?(value) do
      %{fact_key: fact_key, value: value, unit: PreviewHelpers.string(fact, :unit)}
    end
  end

  defp normalize_fact(_fact), do: nil

  defp normalize_impacts(impacts) do
    impacts
    |> Enum.map(&normalize_impact/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_impact(impact) when is_map(impact) do
    subject_id = PreviewHelpers.string(impact, :subject_id)
    impact_type = PreviewHelpers.string(impact, :impact_type)
    severity = PreviewHelpers.string(impact, :severity)
    summary = PreviewHelpers.string(impact, :summary)

    if filled?(subject_id) and filled?(impact_type) and filled?(severity) and filled?(summary) do
      %{
        subject_id: subject_id,
        subject_kind: PreviewHelpers.string(impact, :subject_kind),
        impact_type: impact_type,
        severity: severity,
        summary: summary
      }
    end
  end

  defp normalize_impact(_impact), do: nil

  defp format_window(%{start_at: start_at, end_at: nil}), do: start_at
  defp format_window(%{start_at: start_at, end_at: end_at}), do: start_at <> " to " <> end_at

  defp format_source(source), do: source.source_name <> " (" <> source.source_kind <> ")"

  defp format_fact_value(%{value: value, unit: nil}), do: to_string(value)
  defp format_fact_value(%{value: value, unit: unit}), do: to_string(value) <> " " <> unit

  defp filled?(value) when is_binary(value), do: value != ""
  defp filled?(_value), do: false

  defp scalar?(value) when is_binary(value) or is_boolean(value) or is_number(value), do: true
  defp scalar?(_value), do: false
end
