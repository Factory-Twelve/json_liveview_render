defmodule JsonLiveviewRender.Blocks.SampleRoundSummary do
  @moduledoc """
  Internal experimental sample round summary renderer for reusable lifecycle
  detail and review panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:sample_round_id, :string, required: true)
  attr(:round_label, :string, required: true)
  attr(:status, :string, required: true)
  attr(:summary, :string, required: true)
  attr(:round_type, :string, default: nil)
  attr(:owner, :string, default: nil)
  attr(:requested_at, :string, default: nil)
  attr(:reviewed_at, :string, default: nil)
  attr(:decision_due_at, :string, default: nil)
  attr(:disposition_counts, :list, default: [])
  attr(:findings, :list, default: [])
  attr(:next_steps, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:normalized_counts, normalize_counts(assigns.disposition_counts))
      |> Map.put(:normalized_findings, normalize_findings(assigns.findings))
      |> Map.put(:normalized_steps, normalize_steps(assigns.next_steps))

    ~H"""
    <article
      class="genui-sample-round-summary"
      data-sample-round-id={@sample_round_id}
      data-status={@status}
    >
      <header class="genui-sample-round-summary__header">
        <span class="genui-sample-round-summary__status"><%= @status %></span>
        <h4>Sample round</h4>
      </header>
      <p class="genui-sample-round-summary__label"><%= @round_label %></p>
      <p class="genui-sample-round-summary__summary"><%= @summary %></p>
      <dl class="genui-sample-round-summary__meta">
        <div :if={@round_type}>
          <dt>Round type</dt>
          <dd><%= @round_type %></dd>
        </div>
        <div :if={@owner}>
          <dt>Owner</dt>
          <dd><%= @owner %></dd>
        </div>
        <div :if={@requested_at}>
          <dt>Requested</dt>
          <dd><%= @requested_at %></dd>
        </div>
        <div :if={@reviewed_at}>
          <dt>Reviewed</dt>
          <dd><%= @reviewed_at %></dd>
        </div>
        <div :if={@decision_due_at}>
          <dt>Decision due</dt>
          <dd><%= @decision_due_at %></dd>
        </div>
      </dl>
      <section
        :if={@normalized_counts != []}
        class="genui-sample-round-summary__disposition-counts"
      >
        <h5>Disposition summary</h5>
        <ul>
          <li
            :for={count <- @normalized_counts}
            class="genui-sample-round-summary__disposition-count"
            data-tone={count.tone}
          >
            <strong><%= count.count %></strong>
            <span><%= count.label %></span>
          </li>
        </ul>
      </section>
      <section :if={@normalized_findings != []} class="genui-sample-round-summary__findings">
        <h5>Findings</h5>
        <ul>
          <li
            :for={finding <- @normalized_findings}
            class="genui-sample-round-summary__finding"
            data-finding-id={finding.finding_id}
            data-status={finding.status}
          >
            <div class="genui-sample-round-summary__finding-header">
              <strong><%= finding.area %></strong>
              <span><%= finding.status %></span>
              <span :if={finding.impact}><%= finding.impact %></span>
            </div>
            <p><%= finding.summary %></p>
          </li>
        </ul>
      </section>
      <section :if={@normalized_steps != []} class="genui-sample-round-summary__next-steps">
        <h5>Next steps</h5>
        <ul>
          <li
            :for={step <- @normalized_steps}
            class="genui-sample-round-summary__next-step"
            data-step-id={step.step_id}
            data-status={step.status}
          >
            <div class="genui-sample-round-summary__next-step-header">
              <strong><%= step.label %></strong>
              <span :if={step.status}><%= step.status %></span>
            </div>
            <p :if={step.summary}><%= step.summary %></p>
            <dl :if={step.owner || step.due_at} class="genui-sample-round-summary__next-step-meta">
              <div :if={step.owner}>
                <dt>Owner</dt>
                <dd><%= step.owner %></dd>
              </div>
              <div :if={step.due_at}>
                <dt>Due</dt>
                <dd><%= step.due_at %></dd>
              </div>
            </dl>
          </li>
        </ul>
      </section>
      <div :if={@children != []} class="genui-sample-round-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_counts(counts) do
    counts
    |> Enum.map(&normalize_count/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_count(count) when is_map(count) do
    label = PreviewHelpers.string(count, :label)
    value = integer_value(count, :count)

    if filled?(label) and is_integer(value) do
      %{label: label, count: value, tone: PreviewHelpers.string(count, :tone)}
    end
  end

  defp normalize_count(_count), do: nil

  defp normalize_findings(findings) do
    findings
    |> Enum.map(&normalize_finding/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_finding(finding) when is_map(finding) do
    finding_id = PreviewHelpers.string(finding, :finding_id)
    area = PreviewHelpers.string(finding, :area)
    status = PreviewHelpers.string(finding, :status)
    summary = PreviewHelpers.string(finding, :summary)

    if filled?(finding_id) and filled?(area) and filled?(status) and filled?(summary) do
      %{
        finding_id: finding_id,
        area: area,
        status: status,
        summary: summary,
        impact: PreviewHelpers.string(finding, :impact)
      }
    end
  end

  defp normalize_finding(_finding), do: nil

  defp normalize_steps(steps) do
    steps
    |> Enum.map(&normalize_step/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_step(step) when is_map(step) do
    step_id = PreviewHelpers.string(step, :step_id)
    label = PreviewHelpers.string(step, :label)

    if filled?(step_id) and filled?(label) do
      %{
        step_id: step_id,
        label: label,
        status: PreviewHelpers.string(step, :status),
        summary: PreviewHelpers.string(step, :summary),
        owner: PreviewHelpers.string(step, :owner),
        due_at: PreviewHelpers.string(step, :due_at)
      }
    end
  end

  defp normalize_step(_step), do: nil

  defp integer_value(map, key) do
    case PreviewHelpers.value(map, key) do
      value when is_integer(value) -> value
      _other -> nil
    end
  end

  defp filled?(value) when is_binary(value), do: value != ""
  defp filled?(_value), do: false
end
