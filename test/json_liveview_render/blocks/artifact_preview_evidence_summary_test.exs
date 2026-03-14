defmodule JsonLiveviewRender.Blocks.ArtifactPreviewEvidenceSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.ArtifactPreviewEvidenceSummary

  test "renders evidence totals, breakdown, and refs" do
    html =
      render_component(&ArtifactPreviewEvidenceSummary.render/1,
        artifact_id: "artifact_spec_digest_v3",
        total_count: 3,
        latest_captured_at: "2026-03-01T14:25:00Z",
        summary: "Preview includes the most recent evidence refs used by the artifact.",
        source_breakdown: [
          %{"label" => "Spec sheets", "count" => 1},
          %{"label" => "Emails", "count" => 1},
          %{"label" => "Lab reports", "count" => 1}
        ],
        evidence_refs: [
          %{
            "ref_id" => "evidence_spec_sheet_alpine",
            "title" => "Alpine hoodie tech pack PDF",
            "source_type" => "spec_sheet",
            "captured_at" => "2026-02-18T14:55:00Z",
            "uri" => "https://example.com/specs/alpine-hoodie-2026-02.pdf"
          },
          %{
            "ref_id" => "evidence_supplier_email_zipper",
            "title" => "Supplier zipper question",
            "source_type" => "email",
            "captured_at" => "2026-02-20T09:15:00Z"
          }
        ]
      )

    assert html =~ "Evidence"
    assert html =~ "3"
    assert html =~ "2026-03-01T14:25:00Z"
    assert html =~ "Spec sheets"
    assert html =~ "Alpine hoodie tech pack PDF"
    assert html =~ "spec_sheet"
    assert html =~ "Supplier zipper question"
    assert html =~ "https://example.com/specs/alpine-hoodie-2026-02.pdf"
  end
end
