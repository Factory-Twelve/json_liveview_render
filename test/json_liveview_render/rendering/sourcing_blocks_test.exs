defmodule JsonLiveviewRender.Rendering.SourcingBlocksTest do
  use ExUnit.Case, async: true

  alias JsonLiveviewRender.Blocks.SourcingCatalog
  alias JsonLiveviewRender.Blocks.SourcingRegistry
  alias JsonLiveviewRender.Spec

  @valid_spec %{
    "root" => "panel",
    "elements" => %{
      "panel" => %{
        "type" => "column",
        "props" => %{"gap" => "md"},
        "children" => ["evidence_section", "artifact_section", "approval_section"]
      },
      "evidence_section" => %{
        "type" => "section",
        "props" => %{"title" => "Evidence"},
        "children" => ["evidence_spec_sheet_alpine", "evidence_supplier_email_zipper"]
      },
      "evidence_spec_sheet_alpine" => %{
        "type" => "sourcing_evidence_card",
        "props" => %{
          "ref_id" => "evidence_spec_sheet_alpine",
          "source_type" => "spec_sheet",
          "title" => "Alpine Hoodie tech pack PDF",
          "uri" => "https://example.com/specs/alpine-hoodie-2026-02.pdf",
          "captured_at" => "2026-02-18T14:55:00Z",
          "excerpt" => "Approved fleece composition is 65 percent recycled polyester."
        },
        "children" => []
      },
      "evidence_supplier_email_zipper" => %{
        "type" => "sourcing_evidence_card",
        "props" => %{
          "ref_id" => "evidence_supplier_email_zipper",
          "source_type" => "email",
          "title" => "Supplier zipper question",
          "uri" => "https://example.com/mail/supplier-zipper-question",
          "captured_at" => "2026-02-20T09:15:00Z",
          "excerpt" => "Two zipper finish options remain under consideration."
        },
        "children" => []
      },
      "artifact_section" => %{
        "type" => "section",
        "props" => %{"title" => "Artifacts"},
        "children" => ["artifact_spec_digest_alpine"]
      },
      "artifact_spec_digest_alpine" => %{
        "type" => "sourcing_artifact_summary",
        "props" => %{
          "artifact_id" => "artifact_spec_digest_alpine",
          "artifact_type" => "spec_digest",
          "title" => "Alpine Hoodie spec digest",
          "status" => "ready",
          "version" => "v1",
          "generated_from_evidence_ids" => ["evidence_spec_sheet_alpine"]
        },
        "children" => []
      },
      "approval_section" => %{
        "type" => "section",
        "props" => %{"title" => "Approval"},
        "children" => ["approval_spec_digest_alpine"]
      },
      "approval_spec_digest_alpine" => %{
        "type" => "sourcing_approval_widget",
        "props" => %{
          "approval_id" => "approval_spec_digest_alpine",
          "subject_id" => "artifact_spec_digest_alpine",
          "decision" => "needs_review",
          "actor" => "merch_lead_001",
          "decided_at" => "2026-02-20T11:00:00Z",
          "rationale" => "Confirm zipper finish before final approval.",
          "read_only" => true,
          "disabled_reason" => "Awaiting merch review"
        },
        "children" => [
          "policy_recycled_content_required",
          "approve_artifact",
          "reject_artifact"
        ]
      },
      "policy_recycled_content_required" => %{
        "type" => "sourcing_policy_flag",
        "props" => %{
          "code" => "recycled_content_required",
          "severity" => "high",
          "message" => "Shell fabric must remain at or above the recycled content threshold."
        },
        "children" => []
      },
      "approve_artifact" => %{
        "type" => "sourcing_approval_action",
        "props" => %{
          "action_id" => "approve_artifact",
          "label" => "Approve artifact",
          "tone" => "primary",
          "disabled" => true,
          "disabled_reason" => "Needs zipper confirmation"
        },
        "children" => []
      },
      "reject_artifact" => %{
        "type" => "sourcing_approval_action",
        "props" => %{
          "action_id" => "reject_artifact",
          "label" => "Reject artifact",
          "tone" => "danger"
        },
        "children" => []
      }
    }
  }

  test "validates sourcing side-panel specs" do
    assert {:ok, _spec} = Spec.validate(@valid_spec, SourcingCatalog)
  end

  test "rejects invalid sourcing approval decisions" do
    spec =
      put_in(
        @valid_spec,
        ["elements", "approval_spec_digest_alpine", "props", "decision"],
        "pending"
      )

    assert {:error, reasons} = Spec.validate(spec, SourcingCatalog)
    assert Enum.any?(reasons, fn {tag, _message} -> tag == :invalid_prop_type end)
  end

  test "renders sourcing evidence, artifact, policy, and approval blocks" do
    html =
      JsonLiveviewRender.Test.render_spec(@valid_spec, SourcingCatalog,
        registry: SourcingRegistry,
        current_user: %{},
        bindings: %{}
      )

    assert html =~ "Evidence"
    assert html =~ "Alpine Hoodie tech pack PDF"
    assert html =~ "Supplier zipper question"
    assert html =~ "Artifacts"
    assert html =~ "Alpine Hoodie spec digest"
    assert html =~ "Generated from"
    assert html =~ "Approval"
    assert html =~ "needs_review"
    assert html =~ "Read only"
    assert html =~ "recycled_content_required"
    assert html =~ "Approve artifact"
    assert html =~ "Needs zipper confirmation"
    assert html =~ "Reject artifact"
  end
end
