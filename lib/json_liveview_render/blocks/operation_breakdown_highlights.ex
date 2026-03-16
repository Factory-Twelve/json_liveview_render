defmodule JsonLiveviewRender.Blocks.OperationBreakdownHighlights do
  @moduledoc """
  Internal experimental operation breakdown highlight renderer for reusable
  lifecycle detail and review panels.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Blocks.PreviewHelpers

  attr(:operation_breakdown_id, :string, required: true)
  attr(:breakdown_label, :string, required: true)
  attr(:status, :string, required: true)
  attr(:summary, :string, required: true)
  attr(:supplier_label, :string, default: nil)
  attr(:facility_label, :string, default: nil)
  attr(:total_operations, :integer, default: nil)
  attr(:total_smv, :float, default: nil)
  attr(:manual_share_pct, :float, default: nil)
  attr(:highlights, :list, default: [])
  attr(:flags, :list, default: [])
  attr(:children, :list, default: [])

  def render(assigns) do
    assigns =
      assigns
      |> Map.put(:normalized_highlights, normalize_highlights(assigns.highlights))
      |> Map.put(:normalized_flags, normalize_flags(assigns.flags))

    ~H"""
    <article
      class="genui-operation-breakdown-highlights"
      data-operation-breakdown-id={@operation_breakdown_id}
      data-status={@status}
    >
      <header class="genui-operation-breakdown-highlights__header">
        <span class="genui-operation-breakdown-highlights__status"><%= @status %></span>
        <h4>Operation breakdown</h4>
      </header>
      <p class="genui-operation-breakdown-highlights__label"><%= @breakdown_label %></p>
      <p class="genui-operation-breakdown-highlights__summary"><%= @summary %></p>
      <dl class="genui-operation-breakdown-highlights__meta">
        <div :if={@supplier_label}>
          <dt>Supplier</dt>
          <dd><%= @supplier_label %></dd>
        </div>
        <div :if={@facility_label}>
          <dt>Facility</dt>
          <dd><%= @facility_label %></dd>
        </div>
        <div :if={@total_operations}>
          <dt>Operations</dt>
          <dd><%= @total_operations %></dd>
        </div>
        <div :if={not is_nil(@total_smv)}>
          <dt>Total SMV</dt>
          <dd><%= format_number(@total_smv) %></dd>
        </div>
        <div :if={not is_nil(@manual_share_pct)}>
          <dt>Manual share</dt>
          <dd><%= format_number(@manual_share_pct) %>%</dd>
        </div>
      </dl>
      <section
        :if={@normalized_highlights != []}
        class="genui-operation-breakdown-highlights__highlights"
      >
        <h5>Highlights</h5>
        <ul>
          <li
            :for={highlight <- @normalized_highlights}
            class="genui-operation-breakdown-highlights__highlight"
            data-operation-key={highlight.operation_key}
            data-change-type={highlight.change_type}
          >
            <div class="genui-operation-breakdown-highlights__highlight-header">
              <strong><%= highlight.label %></strong>
              <span :if={highlight.change_type}><%= highlight.change_type %></span>
              <span :if={highlight.workstation}><%= highlight.workstation %></span>
            </div>
            <dl
              :if={not is_nil(highlight.smv) || not is_nil(highlight.cost_share_pct)}
              class="genui-operation-breakdown-highlights__highlight-meta"
            >
              <div :if={not is_nil(highlight.smv)}>
                <dt>SMV</dt>
                <dd><%= format_number(highlight.smv) %></dd>
              </div>
              <div :if={not is_nil(highlight.cost_share_pct)}>
                <dt>Cost share</dt>
                <dd><%= format_number(highlight.cost_share_pct) %>%</dd>
              </div>
            </dl>
            <p :if={highlight.summary}><%= highlight.summary %></p>
          </li>
        </ul>
      </section>
      <section :if={@normalized_flags != []} class="genui-operation-breakdown-highlights__flags">
        <h5>Flags</h5>
        <ul>
          <li
            :for={flag <- @normalized_flags}
            class="genui-operation-breakdown-highlights__flag"
            data-code={flag.code}
            data-severity={flag.severity}
          >
            <div class="genui-operation-breakdown-highlights__flag-header">
              <strong><%= flag.code %></strong>
              <span><%= flag.severity %></span>
            </div>
            <p><%= flag.message %></p>
          </li>
        </ul>
      </section>
      <div :if={@children != []} class="genui-operation-breakdown-highlights__children">
        <%= for child <- @children do %>
          <%= child %>
        <% end %>
      </div>
    </article>
    """
  end

  defp normalize_highlights(highlights) do
    highlights
    |> Enum.map(&normalize_highlight/1)
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_highlight(highlight) when is_map(highlight) do
    operation_key = PreviewHelpers.string(highlight, :operation_key)
    label = PreviewHelpers.string(highlight, :label)

    if filled?(operation_key) and filled?(label) do
      %{
        operation_key: operation_key,
        label: label,
        workstation: PreviewHelpers.string(highlight, :workstation),
        change_type: PreviewHelpers.string(highlight, :change_type),
        smv: number_value(highlight, :smv),
        cost_share_pct: number_value(highlight, :cost_share_pct),
        summary: PreviewHelpers.string(highlight, :summary)
      }
    end
  end

  defp normalize_highlight(_highlight), do: nil

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
