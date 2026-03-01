defmodule JsonLiveviewRenderTest.Companion.ChatCards.FixtureHelper do
  @moduledoc false

  @input_path Path.expand("../fixtures/chat_cards/input/qc_alert.json", __DIR__)

  def input_spec do
    @input_path
    |> File.read!()
    |> Jason.decode!()
  end

  def expected_fixture(relative_path) do
    path = Path.expand("../fixtures/chat_cards/expected/#{relative_path}", __DIR__)
    path |> File.read!() |> Jason.decode!()
  end

  def compile(opts \\ []) do
    base_opts = [
      catalog: JsonLiveviewRenderTest.Companion.ChatCards.Catalog,
      current_user: %{role: :member}
    ]

    JsonLiveviewRender.Companion.ChatCards.compile(input_spec(), Keyword.merge(base_opts, opts))
  end
end
