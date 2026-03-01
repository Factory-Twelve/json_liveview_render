defmodule JsonLiveviewRender.MixProject do
  use Mix.Project

  def project do
    [
      app: :json_liveview_render,
      version: "0.2.0",
      elixir: "~> 1.15",
      description: description(),
      source_url: "https://github.com/Factory-Twelve/json_liveview_render",
      homepage_url: "https://github.com/Factory-Twelve/json_liveview_render",
      package: package(),
      docs: docs(),
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [ci: :test]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"},
      {:phoenix_live_view, "~> 1.1"},
      {:ex_doc, "~> 0.37", only: :dev, runtime: false},
      {:stream_data, "~> 1.1", only: :test}
    ]
  end

  defp description do
    "Agent-safe generative UI framework for Phoenix LiveView (Catalog -> Spec -> Render)."
  end

  defp package do
    [
      licenses: ["MIT"],
      files:
        ~w(lib .formatter.exs mix.exs README.md RELEASE_READINESS.md CHANGELOG.md LEARNINGS.md LICENSE),
      links: %{
        "GitHub" => "https://github.com/Factory-Twelve/json_liveview_render"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "RELEASE_READINESS.md", "CHANGELOG.md", "LEARNINGS.md", "LICENSE"]
    ]
  end

  defp aliases do
    [
      ci: ["format --check-formatted", "compile --warnings-as-errors", "test"]
    ]
  end
end
