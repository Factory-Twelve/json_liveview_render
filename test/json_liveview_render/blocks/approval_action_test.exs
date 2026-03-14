defmodule JsonLiveviewRender.Blocks.ApprovalActionTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JsonLiveviewRender.Blocks.ApprovalAction

  test "renders disabled approval action state" do
    html =
      render_component(&ApprovalAction.render/1,
        action_id: "approve_artifact",
        label: "Approve artifact",
        tone: "primary",
        disabled: true,
        disabled_reason: "Needs zipper confirmation"
      )

    assert html =~ "Approve artifact"
    assert html =~ "Needs zipper confirmation"
    assert html =~ "disabled"
  end
end
