defmodule Mix.Tasks.JsonLiveviewRender.CheckMetadataTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @base_config [
    name: "json_liveview_render",
    app: :json_liveview_render,
    version: "0.2.0",
    source_url: "https://github.com/Factory-Twelve/json_liveview_render",
    package: [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Factory-Twelve/json_liveview_render"}
    ]
  ]

  test "metadata_issues/1 passes for valid metadata" do
    assert [] == Mix.Tasks.JsonLiveviewRender.CheckMetadata.metadata_issues(@base_config)
  end

  test "metadata_issues/1 requires a package name" do
    config =
      Keyword.drop(@base_config, [:name, :app])
      |> Keyword.put(:app, nil)

    issues = Mix.Tasks.JsonLiveviewRender.CheckMetadata.metadata_issues(config)

    assert Enum.any?(issues, &String.contains?(&1, "Missing package name"))
  end

  test "metadata_issues/1 requires a valid source or homepage URL" do
    config = Keyword.put(@base_config, :source_url, "not-a-url")

    issues = Mix.Tasks.JsonLiveviewRender.CheckMetadata.metadata_issues(config)

    assert Enum.any?(issues, &String.contains?(&1, "Missing package URL"))
  end

  test "metadata_issues/1 requires a valid version string" do
    config = Keyword.put(@base_config, :version, "bad-version")

    issues = Mix.Tasks.JsonLiveviewRender.CheckMetadata.metadata_issues(config)

    assert Enum.any?(issues, &String.contains?(&1, "Invalid package version"))
  end

  test "metadata_issues/1 requires licenses in package metadata" do
    config = Keyword.put(@base_config, :package, licenses: [])

    issues = Mix.Tasks.JsonLiveviewRender.CheckMetadata.metadata_issues(config)

    assert Enum.any?(issues, &String.contains?(&1, "Missing or empty package licenses"))
  end

  test "run/1 prints a pass message for valid config" do
    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.CheckMetadata.run([])
      end)

    assert output =~ "mix.exs metadata checks passed."
  end
end
