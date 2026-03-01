defmodule JsonLiveviewRender.Companion.ChatCards do
  @moduledoc """
  Companion pipeline for compiling one filtered GenUI spec into multiple chat-card targets.

  This module is internal/experimental companion scope and intentionally outside the
  stable v0.x core contract.
  """

  alias JsonLiveviewRender.Companion.ChatCards.Router
  alias JsonLiveviewRender.Companion.ChatCards.Target

  @typedoc "Supported companion output targets."
  @type target :: Target.t()

  @typedoc "Slack Block Kit surface selection."
  @type slack_surface :: :message | :home | :modal

  @typedoc "WhatsApp interactive output mode."
  @type whatsapp_mode :: :auto | :buttons | :list

  @typedoc "Normalized action envelope emitted across compiled outputs."
  @type action_envelope :: %{
          required(:version) => String.t(),
          required(:action_id) => String.t(),
          required(:card_id) => String.t(),
          required(:source_platform) => target(),
          required(:metadata) => map()
        }

  @typedoc "Final compile result payload returned by companion APIs."
  @type result :: %{
          required(:filtered_spec) => map(),
          required(:outputs) => %{optional(target()) => map()},
          required(:actions) => [action_envelope()],
          required(:warnings) => [Target.warning()],
          required(:deliveries) => %{optional(target()) => {:ok, term()} | {:error, term()}}
        }

  @doc """
  Compiles a spec into one or more companion chat-card target payloads.

  Required options:
  - `:catalog`
  - `:current_user`

  Optional options:
  - `:targets` (defaults to all companion targets)
  - `:strict` (defaults to `true`)
  - `:authorizer`
  - `:slack_surface` (defaults to `:message`)
  - `:whatsapp_mode` (defaults to `:auto`)
  - `:context`

  ## Examples

      iex> JsonLiveviewRender.Companion.ChatCards.compile(%{}, current_user: %{})
      {:error, {:missing_required_option, :catalog}}

      iex> JsonLiveviewRender.Companion.ChatCards.compile(%{}, catalog: JsonLiveviewRenderTest.Fixtures.Catalog, current_user: %{role: :member}, targets: [:unknown])
      {:error, {:unsupported_target, :unknown}}
  """
  @spec compile(map() | String.t(), keyword()) :: {:ok, result()} | {:error, term()}
  def compile(spec, opts), do: Router.compile(spec, opts)

  @doc """
  Compiles a spec and optionally sends compiled payloads through a sender hook.

  Pass `sender: MySenderModule` to enable delivery. Sender modules must implement
  `deliver/3` from `JsonLiveviewRender.Companion.ChatCards.Sender`.

  ## Examples

      iex> JsonLiveviewRender.Companion.ChatCards.compile_and_send(%{}, current_user: %{})
      {:error, {:missing_required_option, :catalog}}

      iex> JsonLiveviewRender.Companion.ChatCards.compile_and_send(%{}, catalog: JsonLiveviewRenderTest.Fixtures.Catalog, current_user: %{role: :member}, sender: :not_a_module)
      {:error, :invalid_sender}
  """
  @spec compile_and_send(map() | String.t(), keyword()) :: {:ok, result()} | {:error, term()}
  def compile_and_send(spec, opts), do: Router.compile_and_send(spec, opts)
end
