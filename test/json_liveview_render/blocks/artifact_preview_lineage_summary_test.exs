defmodule JsonLiveviewRender.Blocks.ArtifactPreviewLineageSummaryTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.ArtifactPreviewLineageSummary

  test "renders artifact preview lineage groups and refs" do
    html =
      render_component(&ArtifactPreviewLineageSummary.render/1,
        artifact_id: "artifact_spec_digest_v3",
        lineage_state: "superseded",
        summary: "Superseded after cost and trim updates.",
        relationships: [
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
      )

    assert html =~ "Lineage"
    assert html =~ "superseded"
    assert html =~ "Supersedes"
    assert html =~ "Spec digest v1"
    assert html =~ "artifact_spec_digest_v2"
    assert html =~ "Superseded by"
    assert html =~ "Spec digest v4"
    assert html =~ "ready"
  end

  test "ignores malformed nested values instead of crashing" do
    html =
      render_component(&ArtifactPreviewLineageSummary.render/1,
        artifact_id: "artifact_spec_digest_v3",
        lineage_state: "current",
        relationships: [
          %{
            "label" => %{"unexpected" => "shape"},
            "refs" => [%{"artifact_id" => "artifact_spec_digest_v2"}]
          }
        ]
      )

    assert html =~ "No lineage references."
  end
end
