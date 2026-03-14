defmodule JsonLiveviewRender.Rendering.ArtifactPreviewBlocksTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Blocks.ArtifactPreviewCatalog
  alias JsonLiveviewRender.Blocks.ArtifactPreviewRegistry
  alias JsonLiveviewRender.Spec

  @valid_spec %{
    "root" => "panel",
    "elements" => %{
      "panel" => %{
        "type" => "column",
        "props" => %{"gap" => "md"},
        "children" => [
          "artifact_header_section",
          "lineage_section",
          "approval_section",
          "evidence_section"
        ]
      },
      "artifact_header_section" => %{
        "type" => "section",
        "props" => %{"title" => "Artifact"},
        "children" => ["artifact_header"]
      },
      "artifact_header" => %{
        "type" => "artifact_preview_header",
        "props" => %{
          "artifact_id" => "artifact_spec_digest_v3",
          "artifact_type" => "spec_digest",
          "title" => "Spring 2026 alpine hoodie spec digest",
          "status" => "superseded",
          "version" => "v3",
          "summary" => "Shared reference used by Artifact Library and ops review surfaces.",
          "owner" => "merch_lead_001",
          "updated_at" => "2026-03-01T16:15:00Z"
        },
        "children" => []
      },
      "lineage_section" => %{
        "type" => "section",
        "props" => %{"title" => "Lineage"},
        "children" => ["artifact_lineage"]
      },
      "artifact_lineage" => %{
        "type" => "artifact_preview_lineage_summary",
        "props" => %{
          "artifact_id" => "artifact_spec_digest_v3",
          "lineage_state" => "superseded",
          "summary" => "Superseded after cost and trim updates.",
          "relationships" => [
            %{
              "label" => "Supersedes",
              "refs" => [
                %{
                  "artifact_id" => "artifact_spec_digest_v1",
                  "title" => "Spec digest v1",
                  "status" => "archived"
                },
                %{
                  "artifact_id" => "artifact_spec_digest_v2",
                  "title" => "Spec digest v2",
                  "status" => "archived"
                }
              ]
            },
            %{
              "label" => "Superseded by",
              "refs" => [
                %{
                  "artifact_id" => "artifact_spec_digest_v4",
                  "title" => "Spec digest v4",
                  "status" => "ready"
                }
              ]
            }
          ]
        },
        "children" => []
      },
      "approval_section" => %{
        "type" => "section",
        "props" => %{"title" => "Approval"},
        "children" => ["artifact_approval"]
      },
      "artifact_approval" => %{
        "type" => "artifact_preview_approval_summary",
        "props" => %{
          "artifact_id" => "artifact_spec_digest_v3",
          "overall_state" => "needs_review",
          "requested_at" => "2026-03-01T15:00:00Z",
          "summary" => "Merch approved, ops still waiting on final warehouse constraints.",
          "reviewers" => [
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
        },
        "children" => []
      },
      "evidence_section" => %{
        "type" => "section",
        "props" => %{"title" => "Evidence"},
        "children" => ["artifact_evidence"]
      },
      "artifact_evidence" => %{
        "type" => "artifact_preview_evidence_summary",
        "props" => %{
          "artifact_id" => "artifact_spec_digest_v3",
          "total_count" => 3,
          "latest_captured_at" => "2026-03-01T14:25:00Z",
          "summary" => "Preview includes the most recent evidence refs used by the artifact.",
          "source_breakdown" => [
            %{"label" => "Spec sheets", "count" => 1},
            %{"label" => "Emails", "count" => 1},
            %{"label" => "Lab reports", "count" => 1}
          ],
          "evidence_refs" => [
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
        },
        "children" => []
      }
    }
  }

  test "validates artifact preview specs" do
    assert {:ok, _spec} = Spec.validate(@valid_spec, ArtifactPreviewCatalog)
  end

  test "rejects invalid artifact preview evidence totals" do
    spec =
      put_in(@valid_spec, ["elements", "artifact_evidence", "props", "total_count"], "three")

    assert {:error, reasons} = Spec.validate(spec, ArtifactPreviewCatalog)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :invalid_prop_type end)
  end

  test "renders artifact preview blocks" do
    html =
      JsonLiveviewRender.Test.render_spec(@valid_spec, ArtifactPreviewCatalog,
        registry: ArtifactPreviewRegistry,
        current_user: %{},
        bindings: %{}
      )

    assert html =~ "Artifact"
    assert html =~ "Spring 2026 alpine hoodie spec digest"
    assert html =~ "Lineage"
    assert html =~ "Spec digest v4"
    assert html =~ "Approval"
    assert html =~ "Merch lead"
    assert html =~ "Awaiting final warehouse bin fit."
    assert html =~ "Evidence"
    assert html =~ "Spec sheets"
    assert html =~ "Alpine hoodie tech pack PDF"
    assert html =~ "https://example.com/specs/alpine-hoodie-2026-02.pdf"
  end
end
