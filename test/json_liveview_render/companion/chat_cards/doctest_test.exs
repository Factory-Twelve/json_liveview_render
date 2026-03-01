defmodule JsonLiveviewRender.Companion.ChatCards.DoctestTest do
  use ExUnit.Case, async: true

  doctest JsonLiveviewRender.Companion.ChatCards
  doctest JsonLiveviewRender.Companion.ChatCards.Target
  doctest JsonLiveviewRender.Companion.ChatCards.Router
  doctest JsonLiveviewRender.Companion.ChatCards.Bridge
  doctest JsonLiveviewRender.Companion.ChatCards.IR
  doctest JsonLiveviewRender.Companion.ChatCards.Warnings
  doctest JsonLiveviewRender.Companion.ChatCards.Platform.Limits
  doctest JsonLiveviewRender.Companion.ChatCards.Platform.LiveView
  doctest JsonLiveviewRender.Companion.ChatCards.Platform.WebChat
  doctest JsonLiveviewRender.Companion.ChatCards.Platform.Slack
  doctest JsonLiveviewRender.Companion.ChatCards.Platform.Teams
  doctest JsonLiveviewRender.Companion.ChatCards.Platform.WhatsApp
  doctest JsonLiveviewRender.Companion.ChatCards.Sender.HTTP
  doctest JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient
  doctest JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient.Default
end
