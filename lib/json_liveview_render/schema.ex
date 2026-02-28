defmodule JsonLiveviewRender.Schema do
  @moduledoc """
  Stable v0.2 contract for exporting catalog metadata into JSON Schema and prompt text.

  API scope:

  - Stability: v0.2 core contract
  - Included in the v0.3 package scope lock
  """

  alias JsonLiveviewRender.Schema.JSONSchemaBuilder
  alias JsonLiveviewRender.Schema.PromptBuilder

  @doc """
  Builds a JSON Schema definition for the catalog.

  ## Examples

      iex> schema = JsonLiveviewRender.Schema.to_json_schema(JsonLiveviewRenderTest.SchemaFixtures.SmallCatalog)
      iex> schema["type"]
      "object"
      iex> schema["required"]
      ["root", "elements"]
  """
  @spec to_json_schema(module()) :: map()
  def to_json_schema(catalog_module) when is_atom(catalog_module) do
    JSONSchemaBuilder.build(catalog_module)
  end

  @doc """
  Builds prompt text describing available components and prop semantics.

  ## Examples

      iex> prompt = JsonLiveviewRender.Schema.to_prompt(JsonLiveviewRenderTest.SchemaFixtures.SmallCatalog)
      iex> String.starts_with?(prompt, "You generate UI specs for a Phoenix LiveView application.")
      true
      iex> prompt =~ "### metric"
      true
      iex> prompt =~ "label (string, required)"
      true
  """
  @spec to_prompt(module()) :: String.t()
  def to_prompt(catalog_module) when is_atom(catalog_module) do
    PromptBuilder.build(catalog_module)
  end
end
