defmodule JsonLiveviewRender.Blocks.LogisticsScenarioSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.LogisticsScenarioSummary

  test "renders route legs, cost breakdown, risk flags, and alternatives" do
    html =
      render_component(&LogisticsScenarioSummary.render/1,
        scenario_id: "logistics_scenario_alpine_ocean_split",
        scenario_key: "alpine_ocean_split_vietnam_us",
        scenario_status: "at_risk",
        summary:
          "Keep the Hanoi FOB booking and route through Oakland, but tariff exposure and port congestion keep the scenario at risk.",
        shipment_units: 18_000,
        ready_at: "2026-05-08T00:00:00Z",
        estimated_arrival_at: "2026-05-31T00:00:00Z",
        total_transit_days: 22.5,
        origin_country: "VN",
        destination_country: "US",
        incoterm: "FOB",
        signal_ids: ["risk_signal_vietnam_tariff_watch"],
        route_legs: [
          %{
            "sequence" => 2,
            "mode" => "ocean",
            "origin" => "Hai Phong Port",
            "destination" => "Port of Oakland",
            "transit_days" => 19
          },
          %{
            "sequence" => 1,
            "mode" => "truck",
            "origin" => "Peak Hanoi Factory",
            "destination" => "Hai Phong Port",
            "transit_days" => 1.5
          }
        ],
        cost_breakdown: [
          %{"cost_type" => "freight", "amount" => 42_800, "currency" => "USD"},
          %{"cost_type" => "duty", "amount" => 33_750, "currency" => "USD"}
        ],
        risk_flags: [
          %{
            "code" => "tariff_watch_open",
            "severity" => "high",
            "message" =>
              "Tariff watch remains unresolved and could materially increase landed cost."
          }
        ],
        route_alternatives: [
          %{
            "scenario_id" => "logistics_scenario_alpine_air_partial",
            "label" => "Partial air bridge",
            "scenario_status" => "on_track",
            "tradeoff" => "Improves delivery confidence but increases landed cost."
          }
        ]
      )

    assert html =~ "Logistics"
    assert html =~ "22.5"
    assert html =~ "VN to US"
    assert html =~ "risk_signal_vietnam_tariff_watch"
    assert html =~ "1."
    assert html =~ "Peak Hanoi Factory to Hai Phong Port"
    assert html =~ "freight"
    assert html =~ "42800 USD"
    assert html =~ "tariff_watch_open"
    assert html =~ "Partial air bridge"
    assert html =~ "Improves delivery confidence but increases landed cost."
  end
end
