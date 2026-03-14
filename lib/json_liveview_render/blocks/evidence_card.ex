defmodule JsonLiveviewRender.Blocks.EvidenceCard do
  @moduledoc """
  Internal experimental evidence card renderer for sourcing wedge side panels.
  """

  use Phoenix.Component

  attr(:ref_id, :string, required: true)
  attr(:source_type, :string, required: true)
  attr(:title, :string, required: true)
  attr(:uri, :string, required: true)
  attr(:captured_at, :string, required: true)
  attr(:excerpt, :string, default: nil)

  def render(assigns) do
    ~H"""
    <article
      class="genui-sourcing-evidence-card"
      data-ref-id={@ref_id}
      data-source-type={@source_type}
    >
      <header class="genui-sourcing-evidence-card__header">
        <span class="genui-sourcing-evidence-card__source"><%= @source_type %></span>
        <h4><%= @title %></h4>
      </header>
      <p class="genui-sourcing-evidence-card__captured-at"><%= @captured_at %></p>
      <p :if={@excerpt} class="genui-sourcing-evidence-card__excerpt"><%= @excerpt %></p>
      <a
        class="genui-sourcing-evidence-card__link"
        href={@uri}
        rel="noreferrer"
        target="_blank"
      >
        <%= @uri %>
      </a>
    </article>
    """
  end
end
