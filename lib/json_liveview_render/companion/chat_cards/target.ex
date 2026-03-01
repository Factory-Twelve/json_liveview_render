defmodule JsonLiveviewRender.Companion.ChatCards.Target do
  @moduledoc """
  Shared target behavior and helper utilities for chat-card companion renderers.
  """

  @typedoc "Supported output targets for RC1 companion chat-card compilation."
  @type t :: :liveview | :web_chat | :slack | :teams | :whatsapp

  @typedoc "Warning payload shared across targets."
  @type warning :: %{
          required(:code) => atom(),
          required(:target) => t() | :bridge | :delivery,
          required(:path) => [String.t()],
          required(:message) => String.t(),
          required(:meta) => map()
        }

  @typedoc "Action metadata returned by target renderers before envelope projection."
  @type action_ref :: %{
          required(:action_id) => String.t(),
          optional(:metadata) => map()
        }

  @callback render(map(), keyword()) ::
              {:ok, map(), [warning()], [action_ref()]} | {:error, term()}

  @doc """
  Returns the default target order for companion compilation.

  ## Examples

      iex> JsonLiveviewRender.Companion.ChatCards.Target.default_targets()
      [:liveview, :web_chat, :slack, :teams, :whatsapp]
  """
  @spec default_targets() :: [t()]
  def default_targets, do: [:liveview, :web_chat, :slack, :teams, :whatsapp]

  @doc """
  Returns targets that support optional sender-hook delivery.

  ## Examples

      iex> JsonLiveviewRender.Companion.ChatCards.Target.sendable_targets()
      [:slack, :teams, :whatsapp]
  """
  @spec sendable_targets() :: [t()]
  def sendable_targets, do: [:slack, :teams, :whatsapp]

  @doc """
  Resolves the renderer module for a supported target.

  ## Examples

      iex> JsonLiveviewRender.Companion.ChatCards.Target.module_for(:slack)
      {:ok, JsonLiveviewRender.Companion.ChatCards.Platform.Slack}

      iex> JsonLiveviewRender.Companion.ChatCards.Target.module_for(:unknown)
      :error
  """
  @spec module_for(atom()) :: {:ok, module()} | :error
  def module_for(:liveview), do: {:ok, JsonLiveviewRender.Companion.ChatCards.Platform.LiveView}
  def module_for(:web_chat), do: {:ok, JsonLiveviewRender.Companion.ChatCards.Platform.WebChat}
  def module_for(:slack), do: {:ok, JsonLiveviewRender.Companion.ChatCards.Platform.Slack}
  def module_for(:teams), do: {:ok, JsonLiveviewRender.Companion.ChatCards.Platform.Teams}
  def module_for(:whatsapp), do: {:ok, JsonLiveviewRender.Companion.ChatCards.Platform.WhatsApp}
  def module_for(_), do: :error
end
