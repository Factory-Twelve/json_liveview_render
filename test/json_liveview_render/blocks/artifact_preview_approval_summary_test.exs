defmodule JsonLiveviewRender.Blocks.ArtifactPreviewApprovalSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.ArtifactPreviewApprovalSummary

  test "renders mixed reviewer approval states" do
    html =
      render_component(&ArtifactPreviewApprovalSummary.render/1,
        artifact_id: "artifact_spec_digest_v3",
        overall_state: "needs_review",
        requested_at: "2026-03-01T15:00:00Z",
        summary: "Merch approved, ops still waiting on final warehouse constraints.",
        reviewers: [
          %{
            "name" => "Merch lead",
            "status" => "approved",
            "role" => "Merchandising",
            "decided_at" => "2026-03-02T10:30:00Z",
            "note" => "Color and trim set confirmed."
          },
          %{
            "name" => "Ops lead",
            "status" => "needs_review",
            "role" => "Operations",
            "note" => "Awaiting final warehouse bin fit."
          }
        ]
      )

    assert html =~ "Approval"
    assert html =~ "needs_review"
    assert html =~ "2026-03-01T15:00:00Z"
    assert html =~ "Merch lead"
    assert html =~ "approved"
    assert html =~ "Color and trim set confirmed."
    assert html =~ "Ops lead"
    assert html =~ "Awaiting final warehouse bin fit."
  end
end
