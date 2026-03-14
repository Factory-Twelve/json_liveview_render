defmodule JsonLiveviewRender.Blocks.ApprovalWidgetTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.ApprovalWidget

  test "renders read only approval widget state" do
    html =
      render_component(&ApprovalWidget.render/1,
        approval_id: "approval_spec_digest_alpine",
        subject_id: "artifact_spec_digest_alpine",
        decision: "needs_review",
        actor: "merch_lead_001",
        decided_at: "2026-02-20T11:00:00Z",
        rationale: "Confirm zipper finish before final approval.",
        read_only: true,
        disabled_reason: "Awaiting merch review"
      )

    assert html =~ "needs_review"
    assert html =~ "artifact_spec_digest_alpine"
    assert html =~ "merch_lead_001"
    assert html =~ "Confirm zipper finish before final approval."
    assert html =~ "Read only"
    assert html =~ "Awaiting merch review"
  end
end
