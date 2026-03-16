defmodule JsonLiveviewRender.Blocks.RiskSignalSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.RiskSignalSummary

  test "renders risk signal facts and subject impacts" do
    html =
      render_component(&RiskSignalSummary.render/1,
        signal_id: "risk_signal_vietnam_tariff_watch",
        signal_key: "vietnam_apparel_tariff_watch",
        signal_type: "tariff",
        status: "active",
        severity: "high",
        summary:
          "Proposed US tariff surcharge on Vietnam-sourced outerwear could raise landed cost before May bookings lock.",
        observed_at: "2026-03-15T13:45:00Z",
        effective_window: %{"start_at" => "2026-04-01T00:00:00Z"},
        source: %{
          "source_kind" => "trade_feed",
          "source_name" => "Apex Trade Monitor",
          "reference" => "trade-alert-2026-03-15-vn-outerwear"
        },
        facts: [
          %{"fact_key" => "affected_hs_code", "value" => "6201.40"},
          %{"fact_key" => "tariff_delta_pct", "value" => 12.5, "unit" => "percent"}
        ],
        subject_impacts: [
          %{
            "subject_id" => "supplier_peak_textiles",
            "subject_kind" => "supplier",
            "impact_type" => "cost",
            "severity" => "high",
            "summary" => "Supplier pricing requires re-quoting if the surcharge lands."
          }
        ]
      )

    assert html =~ "Risk signal"
    assert html =~ "vietnam_apparel_tariff_watch"
    assert html =~ "Apex Trade Monitor"
    assert html =~ "affected_hs_code"
    assert html =~ "12.5 percent"
    assert html =~ "Subject impacts"
    assert html =~ "supplier_peak_textiles"
    assert html =~ "Supplier pricing requires re-quoting if the surcharge lands."
  end

  test "ignores malformed facts and impacts instead of crashing" do
    html =
      render_component(&RiskSignalSummary.render/1,
        signal_id: "risk_signal_vietnam_tariff_watch",
        signal_key: "vietnam_apparel_tariff_watch",
        signal_type: "tariff",
        status: "active",
        severity: "high",
        summary: "Summary",
        observed_at: "2026-03-15T13:45:00Z",
        source: %{
          "source_kind" => "trade_feed",
          "source_name" => "Apex Trade Monitor",
          "reference" => "trade-alert-2026-03-15-vn-outerwear"
        },
        facts: [%{"fact_key" => %{"unexpected" => "shape"}, "value" => "6201.40"}],
        subject_impacts: [%{"subject_id" => "supplier_peak_textiles"}]
      )

    refute html =~ "6201.40"
    refute html =~ "Subject impacts"
  end
end
