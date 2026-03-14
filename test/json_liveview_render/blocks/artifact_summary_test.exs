defmodule JsonLiveviewRender.Blocks.ArtifactSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.ArtifactSummary

  test "renders sourcing artifact summary and evidence refs" do
    html =
      render_component(&ArtifactSummary.render/1,
        artifact_id: "artifact_spec_digest_alpine",
        artifact_type: "spec_digest",
        title: "Alpine Hoodie spec digest",
        status: "ready",
        version: "v1",
        generated_from_evidence_ids: ["evidence_spec_sheet_alpine"]
      )

    assert html =~ "Alpine Hoodie spec digest"
    assert html =~ "spec_digest"
    assert html =~ "ready"
    assert html =~ "v1"
    assert html =~ "Generated from"
    assert html =~ "evidence_spec_sheet_alpine"
  end
end
