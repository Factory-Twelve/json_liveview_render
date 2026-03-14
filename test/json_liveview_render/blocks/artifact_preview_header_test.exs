defmodule JsonLiveviewRender.Blocks.ArtifactPreviewHeaderTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.ArtifactPreviewHeader

  test "renders artifact preview header metadata" do
    html =
      render_component(&ArtifactPreviewHeader.render/1,
        artifact_id: "artifact_spec_digest_v3",
        artifact_type: "spec_digest",
        title: "Spring 2026 alpine hoodie spec digest",
        status: "superseded",
        version: "v3",
        summary: "Shared reference used by Artifact Library and ops review surfaces.",
        owner: "merch_lead_001",
        updated_at: "2026-03-01T16:15:00Z"
      )

    assert html =~ "Spring 2026 alpine hoodie spec digest"
    assert html =~ "spec_digest"
    assert html =~ "superseded"
    assert html =~ "v3"
    assert html =~ "Shared reference used by Artifact Library and ops review surfaces."
    assert html =~ "merch_lead_001"
    assert html =~ "2026-03-01T16:15:00Z"
  end
end
