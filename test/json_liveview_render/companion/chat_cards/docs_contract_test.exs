defmodule JsonLiveviewRender.Companion.ChatCards.DocsContractTest do
  use ExUnit.Case, async: true

  @modules [
    JsonLiveviewRender.Companion.ChatCards,
    JsonLiveviewRender.Companion.ChatCards.Target,
    JsonLiveviewRender.Companion.ChatCards.Router,
    JsonLiveviewRender.Companion.ChatCards.Bridge,
    JsonLiveviewRender.Companion.ChatCards.IR,
    JsonLiveviewRender.Companion.ChatCards.Warnings,
    JsonLiveviewRender.Companion.ChatCards.Platform.Limits,
    JsonLiveviewRender.Companion.ChatCards.Platform.LiveView,
    JsonLiveviewRender.Companion.ChatCards.Platform.WebChat,
    JsonLiveviewRender.Companion.ChatCards.Platform.Slack,
    JsonLiveviewRender.Companion.ChatCards.Platform.Teams,
    JsonLiveviewRender.Companion.ChatCards.Platform.WhatsApp,
    JsonLiveviewRender.Companion.ChatCards.Sender,
    JsonLiveviewRender.Companion.ChatCards.Sender.HTTP,
    JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient,
    JsonLiveviewRender.Companion.ChatCards.Sender.HTTPClient.Default
  ]

  test "companion modules include moduledoc and public docs/spec contracts" do
    Enum.each(@modules, fn module ->
      assert {:docs_v1, _, _, _, moduledoc, _, docs} = Code.fetch_docs(module)
      assert moduledoc not in [:none, :hidden]

      specs =
        case Code.Typespec.fetch_specs(module) do
          {:ok, entries} -> Map.new(entries)
          :error -> %{}
        end

      public_functions =
        module
        |> Kernel.apply(:__info__, [:functions])
        |> Enum.reject(fn {name, arity} ->
          {name, arity} in [__info__: 1, module_info: 0, module_info: 1]
        end)

      Enum.each(public_functions, fn {name, arity} ->
        assert Map.has_key?(specs, {name, arity}),
               "missing @spec for #{inspect(module)}.#{name}/#{arity}"

        doc_entry =
          Enum.find(docs, fn
            {{:function, doc_name, doc_arity}, _, _, _, _} ->
              doc_name == name and doc_arity == arity

            _ ->
              false
          end)

        assert doc_entry, "missing @doc for #{inspect(module)}.#{name}/#{arity}"

        {{:function, _, _}, _, _, doc, _} = doc_entry

        case doc do
          :hidden ->
            :ok

          :none ->
            flunk("missing @doc for #{inspect(module)}.#{name}/#{arity}")

          %{"en" => text} when is_binary(text) ->
            assert String.contains?(text, "## Examples"),
                   "missing ## Examples section for #{inspect(module)}.#{name}/#{arity}"

          other ->
            flunk(
              "unexpected doc format #{inspect(other)} for #{inspect(module)}.#{name}/#{arity}"
            )
        end
      end)
    end)
  end
end
