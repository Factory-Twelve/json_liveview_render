defmodule Mix.Tasks.JsonLiveviewRender.CheckMetadata do
  use Mix.Task

  @shortdoc "Validate mix.exs package metadata required for Hex releases."
  @moduledoc """
  Validates package metadata fields in `mix.exs` that should be checked before
  publishing. This keeps release metadata consistent and avoids avoidable Hex
  publish failures.
  """

  @url_pattern ~r/^https?:\/\/\S+$/

  @impl true
  def run([]) do
    project = Mix.Project.config()

    case metadata_issues(project) do
      [] ->
        Mix.shell().info("mix.exs metadata checks passed.")

      issues ->
        Enum.each(issues, &Mix.shell().error("  #{&1}"))
        Mix.raise("mix.exs metadata checks failed. Fix issues before publishing.")
    end
  end

  def run(_args),
    do: Mix.raise("mix json_liveview_render.check_metadata does not accept arguments.")

  @doc """
  Returns a list of metadata validation errors for the given `Mix.Project` config.
  """
  @spec metadata_issues(keyword()) :: [String.t()]
  def metadata_issues(project_config) when is_list(project_config) do
    []
    |> add_issue(name_issue(project_config))
    |> add_issue(url_issue(project_config))
    |> add_issue(version_issue(project_config))
    |> add_issue(licenses_issue(project_config))
    |> add_issue(links_issue(project_config))
  end

  def metadata_issues(_), do: ["mix.exs metadata is not a keyword list."]

  defp add_issue(issues, nil), do: issues
  defp add_issue(issues, issue), do: issues ++ [issue]

  defp name_issue(project) do
    cond do
      has_valid_name?(project) ->
        nil

      true ->
        "Missing package name. Set `app` (or `name`) in your Mix project metadata."
    end
  end

  defp has_valid_name?(project) do
    explicit_name =
      project
      |> Keyword.get(:name)
      |> normalize_string_value()

    cond do
      explicit_name not in [nil, ""] ->
        true

      project[:app] in [nil, false] ->
        false

      true ->
        is_atom(project[:app])
    end
  end

  defp url_issue(project) do
    source_url = Keyword.get(project, :source_url)
    homepage_url = Keyword.get(project, :homepage_url)

    cond do
      valid_url?(source_url) ->
        nil

      valid_url?(homepage_url) ->
        nil

      true ->
        "Missing package URL. Set `source_url` (preferred) or `homepage_url` to a valid URL."
    end
  end

  defp version_issue(project) do
    case Keyword.get(project, :version) do
      nil ->
        "Missing package version."

      version when not is_binary(version) ->
        "Invalid package version; expected a string."

      version ->
        case Version.parse(version) do
          {:ok, _} -> nil
          :error -> "Invalid package version: #{inspect(version)}."
        end
    end
  end

  defp licenses_issue(project) do
    licenses =
      get_in(project, [:package, :licenses]) ||
        Keyword.get(project[:package] || [], :licenses, [])

    cond do
      is_list(licenses) and Enum.any?(licenses, &valid_license?/1) ->
        nil

      is_list(licenses) ->
        "Missing or empty package licenses. Add a non-empty `licenses` list under `package`."

      true ->
        "Invalid package licenses configuration. Set `licenses` to a non-empty list under `package`."
    end
  end

  defp valid_license?(value) do
    is_binary(value) and normalize_string_value(value) != ""
  end

  defp links_issue(project) do
    links = Keyword.get(project[:package] || [], :links, %{})
    url = preferred_url(project)

    cond do
      is_map(links) and links != %{} and url != nil ->
        if Enum.any?(Map.values(links), &(&1 == url)) do
          nil
        else
          "Missing package link for source URL. Add `\"GitHub\" => #{inspect(url)}` to `package[:links]`."
        end

      true ->
        nil
    end
  end

  defp preferred_url(project) do
    Keyword.get(project, :source_url) || Keyword.get(project, :homepage_url)
  end

  defp valid_url?(url) when is_binary(url),
    do: Regex.match?(@url_pattern, normalize_string_value(url))

  defp valid_url?(_), do: false

  defp normalize_string_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_string_value(_), do: nil
end
