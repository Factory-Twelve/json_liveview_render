defmodule JsonLiveviewRender.Blocks.LogisticsScenarioSummary do
  @moduledoc """
  Internal experimental logistics scenario summary renderer for reusable depth
  review panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:scenario_id, :string, required: true)
  attr(:scenario_key, :string, required: true)
  attr(:scenario_status, :string, required: true)
  attr(:summary, :string, required: true)
  attr(:shipment_units, :integer, default: nil)
  attr(:ready_at, :string, default: nil)
  attr(:estimated_arrival_at, :string, default: nil)
  attr(:total_transit_days, :float, required: true)
  attr(:origin_country, :string, default: nil)
  attr(:destination_country, :string, default: nil)
  attr(:incoterm, :string, default: nil)
  attr(:signal_ids, :list, default: [])
  attr(:route_legs, :list, default: [])
  attr(:cost_breakdown, :list, default: [])
  attr(:risk_flags, :list, default: [])
  attr(:route_alternatives, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:normalized_signal_ids, normalize_string_list(assigns.signal_ids))
      |> Map.put(:normalized_legs, normalize_route_legs(assigns.route_legs))
      |> Map.put(:normalized_costs, normalize_costs(assigns.cost_breakdown))
      |> Map.put(:normalized_risk_flags, normalize_flags(assigns.risk_flags))
      |> Map.put(:normalized_alternatives, normalize_alternatives(assigns.route_alternatives))

    ~H"""
    <article
      class="genui-logistics-scenario-summary"
      data-scenario-id={@scenario_id}
      data-scenario-status={@scenario_status}
    >
      <header class="genui-logistics-scenario-summary__header">
        <span class="genui-logistics-scenario-summary__status"><%= @scenario_status %></span>
        <h4>Logistics</h4>
      </header>
      <p class="genui-logistics-scenario-summary__key"><%= @scenario_key %></p>
      <p class="genui-logistics-scenario-summary__summary"><%= @summary %></p>
      <dl class="genui-logistics-scenario-summary__meta">
        <div :if={@shipment_units}>
          <dt>Units</dt>
          <dd><%= @shipment_units %></dd>
        </div>
        <div :if={@ready_at}>
          <dt>Ready</dt>
          <dd><%= @ready_at %></dd>
        </div>
        <div :if={@estimated_arrival_at}>
          <dt>Estimated arrival</dt>
          <dd><%= @estimated_arrival_at %></dd>
        </div>
        <div>
          <dt>Transit days</dt>
          <dd><%= format_number(@total_transit_days) %></dd>
        </div>
        <div :if={@origin_country && @destination_country}>
          <dt>Lane</dt>
          <dd><%= @origin_country %> to <%= @destination_country %></dd>
        </div>
        <div :if={@incoterm}>
          <dt>Incoterm</dt>
          <dd><%= @incoterm %></dd>
        </div>
        <div :if={@normalized_signal_ids != []}>
          <dt>Signals</dt>
          <dd><%= Enum.join(@normalized_signal_ids, ", ") %></dd>
        </div>
      </dl>
      <section :if={@normalized_legs != []} class="genui-logistics-scenario-summary__route">
        <h5>Route plan</h5>
        <ol>
          <li
            :for={leg <- @normalized_legs}
            class="genui-logistics-scenario-summary__leg"
            data-sequence={leg.sequence}
          >
            <div class="genui-logistics-scenario-summary__leg-header">
              <strong><%= leg.sequence %>.</strong>
              <span><%= leg.mode %></span>
              <span><%= format_number(leg.transit_days) %> days</span>
            </div>
            <p><%= leg.origin %> to <%= leg.destination %></p>
          </li>
        </ol>
      </section>
      <section :if={@normalized_costs != []} class="genui-logistics-scenario-summary__costs">
        <h5>Cost breakdown</h5>
        <ul>
          <li
            :for={cost <- @normalized_costs}
            class="genui-logistics-scenario-summary__cost"
            data-cost-type={cost.cost_type}
          >
            <span><%= cost.cost_type %></span>
            <strong><%= format_amount(cost.amount, cost.currency) %></strong>
          </li>
        </ul>
      </section>
      <section
        :if={@normalized_risk_flags != []}
        class="genui-logistics-scenario-summary__risk-flags"
      >
        <h5>Risk flags</h5>
        <ul>
          <li
            :for={flag <- @normalized_risk_flags}
            class="genui-logistics-scenario-summary__risk-flag"
            data-code={flag.code}
            data-severity={flag.severity}
          >
            <div class="genui-logistics-scenario-summary__risk-flag-header">
              <strong><%= flag.code %></strong>
              <span><%= flag.severity %></span>
            </div>
            <p><%= flag.message %></p>
          </li>
        </ul>
      </section>
      <section
        :if={@normalized_alternatives != []}
        class="genui-logistics-scenario-summary__alternatives"
      >
        <h5>Alternatives</h5>
        <ul>
          <li
            :for={alternative <- @normalized_alternatives}
            class="genui-logistics-scenario-summary__alternative"
            data-scenario-id={alternative.scenario_id}
            data-scenario-status={alternative.scenario_status}
          >
            <div class="genui-logistics-scenario-summary__alternative-header">
              <strong><%= alternative.label %></strong>
              <span :if={alternative.scenario_status}><%= alternative.scenario_status %></span>
            </div>
            <p :if={alternative.tradeoff}><%= alternative.tradeoff %></p>
          </li>
        </ul>
      </section>
      <div :if={@children != []} class="genui-logistics-scenario-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_route_legs(legs) do
    legs
    |> Enum.map(&normalize_leg/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.sequence)
  end

  defp normalize_leg(leg) when is_map(leg) do
    sequence = PreviewHelpers.integer(leg, :sequence, -1)
    mode = PreviewHelpers.string(leg, :mode)
    origin = PreviewHelpers.string(leg, :origin)
    destination = PreviewHelpers.string(leg, :destination)
    transit_days = number_value(leg, :transit_days)

    if sequence > 0 and filled?(mode) and filled?(origin) and filled?(destination) and
         is_number(transit_days) do
      %{
        sequence: sequence,
        mode: mode,
        origin: origin,
        destination: destination,
        transit_days: transit_days
      }
    end
  end

  defp normalize_leg(_leg), do: nil

  defp normalize_costs(costs) do
    costs
    |> Enum.map(&normalize_cost/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_cost(cost) when is_map(cost) do
    cost_type = PreviewHelpers.string(cost, :cost_type)
    currency = PreviewHelpers.string(cost, :currency)
    amount = number_value(cost, :amount)

    if filled?(cost_type) and filled?(currency) and is_number(amount) do
      %{cost_type: cost_type, amount: amount, currency: currency}
    end
  end

  defp normalize_cost(_cost), do: nil

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

  defp normalize_alternatives(alternatives) do
    alternatives
    |> Enum.map(&normalize_alternative/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_alternative(alternative) when is_map(alternative) do
    scenario_id = PreviewHelpers.string(alternative, :scenario_id)

    if filled?(scenario_id) do
      %{
        scenario_id: scenario_id,
        label: PreviewHelpers.string(alternative, :label, scenario_id),
        scenario_status: PreviewHelpers.string(alternative, :scenario_status),
        tradeoff: PreviewHelpers.string(alternative, :tradeoff)
      }
    end
  end

  defp normalize_alternative(_alternative), do: nil

  defp normalize_string_list(values) do
    values
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
  end

  defp format_amount(amount, currency), do: format_number(amount) <> " " <> currency

  defp format_number(value) when is_integer(value), do: Integer.to_string(value)

  defp format_number(value) when is_float(value) do
    value
    |> :erlang.float_to_binary(decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
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
