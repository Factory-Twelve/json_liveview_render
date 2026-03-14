defmodule JsonLiveviewRender.Blocks.EvidenceCardTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.EvidenceCard

  test "renders sourcing evidence card metadata" do
    html =
      render_component(&EvidenceCard.render/1,
        ref_id: "evidence_spec_sheet_alpine",
        source_type: "spec_sheet",
        title: "Alpine Hoodie tech pack PDF",
        uri: "https://example.com/specs/alpine-hoodie-2026-02.pdf",
        captured_at: "2026-02-18T14:55:00Z",
        excerpt: "Approved fleece composition is 65 percent recycled polyester."
      )

    assert html =~ "Alpine Hoodie tech pack PDF"
    assert html =~ "spec_sheet"
    assert html =~ "2026-02-18T14:55:00Z"
    assert html =~ "Approved fleece composition is 65 percent recycled polyester."
    assert html =~ "https://example.com/specs/alpine-hoodie-2026-02.pdf"
  end
end
