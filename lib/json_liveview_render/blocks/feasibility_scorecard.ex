defmodule JsonLiveviewRender.Blocks.FeasibilityScorecard do
  @moduledoc """
  Internal experimental feasibility scorecard renderer for reusable depth
  review panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:feasibility_id, :string, required: true)
  attr(:status, :string, required: true)
  attr(:confidence, :float, required: true)
  attr(:summary, :string, required: true)
  attr(:requested_units, :integer, default: nil)
  attr(:target_ship_date, :string, default: nil)
  attr(:requested_currency, :string, default: nil)
  attr(:recommended_plan_id, :string, default: nil)
  attr(:candidate_plans, :list, default: [])
  attr(:constraints, :list, default: [])
  attr(:warnings, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:normalized_plans, normalize_candidate_plans(assigns.candidate_plans))
      |> Map.put(:normalized_constraints, normalize_constraints(assigns.constraints))
      |> Map.put(:normalized_warnings, normalize_flags(assigns.warnings))

    ~H"""
    <article
      class="genui-feasibility-scorecard"
      data-feasibility-id={@feasibility_id}
      data-status={@status}
      data-confidence={@confidence}
    >
      <header class="genui-feasibility-scorecard__header">
        <span class="genui-feasibility-scorecard__status"><%= @status %></span>
        <h4>Feasibility</h4>
        <span class="genui-feasibility-scorecard__confidence">
          Confidence <%= format_number(@confidence) %>
        </span>
      </header>
      <p class="genui-feasibility-scorecard__summary"><%= @summary %></p>
      <dl class="genui-feasibility-scorecard__meta">
        <div :if={@requested_units}>
          <dt>Requested units</dt>
          <dd><%= @requested_units %></dd>
        </div>
        <div :if={@target_ship_date}>
          <dt>Target ship date</dt>
          <dd><%= @target_ship_date %></dd>
        </div>
        <div :if={@recommended_plan_id}>
          <dt>Recommended plan</dt>
          <dd><%= @recommended_plan_id %></dd>
        </div>
      </dl>
      <section :if={@normalized_plans != []} class="genui-feasibility-scorecard__plans">
        <h5>Candidate plans</h5>
        <ul>
          <li
            :for={plan <- @normalized_plans}
            class="genui-feasibility-scorecard__plan"
            data-plan-id={plan.plan_id}
          >
            <div class="genui-feasibility-scorecard__plan-header">
              <strong><%= plan.supplier_id %></strong>
              <span><%= plan.plan_id %></span>
            </div>
            <p class="genui-feasibility-scorecard__plan-facility"><%= plan.facility_id %></p>
            <dl class="genui-feasibility-scorecard__plan-meta">
              <div :if={plan.earliest_start_at}>
                <dt>Start</dt>
                <dd><%= plan.earliest_start_at %></dd>
              </div>
              <div :if={plan.earliest_completion_at}>
                <dt>Completion</dt>
                <dd><%= plan.earliest_completion_at %></dd>
              </div>
              <div>
                <dt>Capacity</dt>
                <dd><%= plan.available_capacity_units %></dd>
              </div>
              <div>
                <dt>Unit cost</dt>
                <dd><%= format_amount(plan.estimated_unit_cost, @requested_currency) %></dd>
              </div>
            </dl>
          </li>
        </ul>
      </section>
      <section :if={@normalized_constraints != []} class="genui-feasibility-scorecard__constraints">
        <h5>Constraints</h5>
        <ul>
          <li
            :for={constraint <- @normalized_constraints}
            class="genui-feasibility-scorecard__constraint"
            data-constraint-key={constraint.constraint_key}
            data-severity={constraint.severity}
            data-blocking={constraint.blocking}
          >
            <div class="genui-feasibility-scorecard__constraint-header">
              <strong><%= constraint.constraint_key %></strong>
              <span><%= constraint.category %></span>
              <span><%= constraint.severity %></span>
              <span :if={constraint.blocking}>blocking</span>
            </div>
            <p class="genui-feasibility-scorecard__constraint-summary"><%= constraint.summary %></p>
            <p
              :if={constraint.related_subject_ids != []}
              class="genui-feasibility-scorecard__constraint-subjects"
            >
              <%= Enum.join(constraint.related_subject_ids, ", ") %>
            </p>
          </li>
        </ul>
      </section>
      <section :if={@normalized_warnings != []} class="genui-feasibility-scorecard__warnings">
        <h5>Warnings</h5>
        <ul>
          <li
            :for={warning <- @normalized_warnings}
            class="genui-feasibility-scorecard__warning"
            data-code={warning.code}
            data-severity={warning.severity}
          >
            <div class="genui-feasibility-scorecard__warning-header">
              <strong><%= warning.code %></strong>
              <span><%= warning.severity %></span>
            </div>
            <p><%= warning.message %></p>
          </li>
        </ul>
      </section>
      <div :if={@children != []} class="genui-feasibility-scorecard__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_candidate_plans(plans) do
    plans
    |> Enum.map(&normalize_candidate_plan/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_candidate_plan(plan) when is_map(plan) do
    plan_id = PreviewHelpers.string(plan, :plan_id)
    supplier_id = PreviewHelpers.string(plan, :supplier_id)
    facility_id = PreviewHelpers.string(plan, :facility_id)
    available_capacity_units = integer_value(plan, :available_capacity_units)
    estimated_unit_cost = number_value(plan, :estimated_unit_cost)

    if filled?(plan_id) and filled?(supplier_id) and filled?(facility_id) and
         is_integer(available_capacity_units) and is_number(estimated_unit_cost) do
      %{
        plan_id: plan_id,
        supplier_id: supplier_id,
        facility_id: facility_id,
        earliest_start_at: PreviewHelpers.string(plan, :earliest_start_at),
        earliest_completion_at: PreviewHelpers.string(plan, :earliest_completion_at),
        available_capacity_units: available_capacity_units,
        estimated_unit_cost: estimated_unit_cost
      }
    end
  end

  defp normalize_candidate_plan(_plan), do: nil

  defp normalize_constraints(constraints) do
    constraints
    |> Enum.map(&normalize_constraint/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_constraint(constraint) when is_map(constraint) do
    constraint_key = PreviewHelpers.string(constraint, :constraint_key)
    category = PreviewHelpers.string(constraint, :category)
    severity = PreviewHelpers.string(constraint, :severity)
    summary = PreviewHelpers.string(constraint, :summary)

    if filled?(constraint_key) and filled?(category) and filled?(severity) and filled?(summary) do
      %{
        constraint_key: constraint_key,
        category: category,
        severity: severity,
        blocking: PreviewHelpers.boolean(constraint, :blocking),
        summary: summary,
        related_subject_ids:
          normalize_string_list(PreviewHelpers.list(constraint, :related_subject_ids))
      }
    end
  end

  defp normalize_constraint(_constraint), do: nil

  defp normalize_flags(flags) do
    flags
    |> Enum.map(&normalize_flag/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_flag(flag) when is_map(flag) do
    code = PreviewHelpers.string(flag, :code)
    severity = PreviewHelpers.string(flag, :severity)
    message = PreviewHelpers.string(flag, :message)

    if filled?(code) and filled?(severity) and filled?(message) do
      %{code: code, severity: severity, message: message}
    end
  end

  defp normalize_flag(_flag), do: nil

  defp normalize_string_list(values) do
    values
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
  end

  defp format_amount(amount, nil), do: format_number(amount)
  defp format_amount(amount, currency), do: format_number(amount) <> " " <> currency

  defp format_number(value) when is_integer(value), do: Integer.to_string(value)

  defp format_number(value) when is_float(value) do
    value
    |> :erlang.float_to_binary(decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp integer_value(map, key) do
    case PreviewHelpers.value(map, key) do
      value when is_integer(value) -> value
      _other -> nil
    end
  end

  defp number_value(map, key) do
    case PreviewHelpers.value(map, key) do
      value when is_integer(value) or is_float(value) -> value
      _other -> nil
    end
  end

  defp filled?(value) when is_binary(value), do: value != ""
  defp filled?(_value), do: false
end
