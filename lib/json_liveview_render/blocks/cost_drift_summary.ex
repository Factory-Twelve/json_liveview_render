defmodule JsonLiveviewRender.Blocks.CostDriftSummary do
  @moduledoc """
  Internal experimental cost drift renderer for reusable lifecycle detail and
  review panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:cost_summary_id, :string, required: true)
  attr(:stage_label, :string, required: true)
  attr(:status, :string, required: true)
  attr(:summary, :string, required: true)
  attr(:currency, :string, default: nil)
  attr(:estimated_total, :float, required: true)
  attr(:negotiated_total, :float, required: true)
  attr(:approved_total, :float, default: nil)
  attr(:delta_total, :float, default: nil)
  attr(:stage_rows, :list, default: [])
  attr(:drivers, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:normalized_stage_rows, normalize_stage_rows(assigns.stage_rows))
      |> Map.put(:normalized_drivers, normalize_drivers(assigns.drivers))

    ~H"""
    <article
      class="genui-cost-drift-summary"
      data-cost-summary-id={@cost_summary_id}
      data-status={@status}
    >
      <header class="genui-cost-drift-summary__header">
        <span class="genui-cost-drift-summary__status"><%= @status %></span>
        <h4>Cost drift</h4>
      </header>
      <p class="genui-cost-drift-summary__label"><%= @stage_label %></p>
      <p class="genui-cost-drift-summary__summary"><%= @summary %></p>
      <section class="genui-cost-drift-summary__totals">
        <h5>Totals</h5>
        <ul>
          <li class="genui-cost-drift-summary__total" data-kind="estimated">
            <span>Estimated</span>
            <strong><%= format_amount(@estimated_total, @currency) %></strong>
          </li>
          <li class="genui-cost-drift-summary__total" data-kind="negotiated">
            <span>Negotiated</span>
            <strong><%= format_amount(@negotiated_total, @currency) %></strong>
          </li>
          <li
            :if={not is_nil(@approved_total)}
            class="genui-cost-drift-summary__total"
            data-kind="approved"
          >
            <span>Approved</span>
            <strong><%= format_amount(@approved_total, @currency) %></strong>
          </li>
          <li
            :if={not is_nil(@delta_total)}
            class="genui-cost-drift-summary__total"
            data-kind="delta"
          >
            <span>Delta</span>
            <strong><%= format_amount(@delta_total, @currency) %></strong>
          </li>
        </ul>
      </section>
      <section :if={@normalized_stage_rows != []} class="genui-cost-drift-summary__stage-rows">
        <h5>Stage breakdown</h5>
        <ul>
          <li
            :for={row <- @normalized_stage_rows}
            class="genui-cost-drift-summary__stage-row"
            data-stage-key={row.stage_key}
          >
            <div class="genui-cost-drift-summary__stage-row-header">
              <strong><%= row.stage_label %></strong>
            </div>
            <p :if={row.summary}><%= row.summary %></p>
            <dl class="genui-cost-drift-summary__stage-row-values">
              <div :if={not is_nil(row.estimated_amount)}>
                <dt>Estimated</dt>
                <dd><%= format_amount(row.estimated_amount, @currency) %></dd>
              </div>
              <div :if={not is_nil(row.negotiated_amount)}>
                <dt>Negotiated</dt>
                <dd><%= format_amount(row.negotiated_amount, @currency) %></dd>
              </div>
              <div :if={not is_nil(row.approved_amount)}>
                <dt>Approved</dt>
                <dd><%= format_amount(row.approved_amount, @currency) %></dd>
              </div>
              <div :if={not is_nil(row.delta_amount)}>
                <dt>Delta</dt>
                <dd><%= format_amount(row.delta_amount, @currency) %></dd>
              </div>
            </dl>
          </li>
        </ul>
      </section>
      <section :if={@normalized_drivers != []} class="genui-cost-drift-summary__drivers">
        <h5>Drift drivers</h5>
        <ul>
          <li
            :for={driver <- @normalized_drivers}
            class="genui-cost-drift-summary__driver"
            data-driver-key={driver.driver_key}
            data-direction={driver.direction}
          >
            <div class="genui-cost-drift-summary__driver-header">
              <strong><%= driver.label %></strong>
              <span :if={driver.direction}><%= driver.direction %></span>
              <span :if={not is_nil(driver.amount)}>
                <%= format_amount(driver.amount, @currency) %>
              </span>
            </div>
            <p :if={driver.summary}><%= driver.summary %></p>
          </li>
        </ul>
      </section>
      <div :if={@children != []} class="genui-cost-drift-summary__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_stage_rows(rows) do
    rows
    |> Enum.map(&normalize_stage_row/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_stage_row(row) when is_map(row) do
    stage_key = PreviewHelpers.string(row, :stage_key)
    stage_label = PreviewHelpers.string(row, :stage_label)
    estimated_amount = number_value(row, :estimated_amount)
    negotiated_amount = number_value(row, :negotiated_amount)
    approved_amount = number_value(row, :approved_amount)
    delta_amount = number_value(row, :delta_amount)

    if filled?(stage_key) and filled?(stage_label) and
         Enum.any?(
           [estimated_amount, negotiated_amount, approved_amount, delta_amount],
           &is_number/1
         ) do
      %{
        stage_key: stage_key,
        stage_label: stage_label,
        estimated_amount: estimated_amount,
        negotiated_amount: negotiated_amount,
        approved_amount: approved_amount,
        delta_amount: delta_amount,
        summary: PreviewHelpers.string(row, :summary)
      }
    end
  end

  defp normalize_stage_row(_row), do: nil

  defp normalize_drivers(drivers) do
    drivers
    |> Enum.map(&normalize_driver/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_driver(driver) when is_map(driver) do
    driver_key = PreviewHelpers.string(driver, :driver_key)
    label = PreviewHelpers.string(driver, :label)

    if filled?(driver_key) and filled?(label) do
      %{
        driver_key: driver_key,
        label: label,
        direction: PreviewHelpers.string(driver, :direction),
        amount: number_value(driver, :amount),
        summary: PreviewHelpers.string(driver, :summary)
      }
    end
  end

  defp normalize_driver(_driver), do: nil

  defp format_amount(amount, nil), do: format_number(amount)
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
