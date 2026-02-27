defmodule JsonLiveviewRender.Schema do
  @moduledoc """
  Stable v0.2 contract for exporting catalog metadata into JSON Schema and prompt text.

  API scope:

  - Stability: v0.2 core contract
  - Included in the v0.3 package scope lock
  """

  alias JsonLiveviewRender.Schema.JSONSchemaBuilder
  alias JsonLiveviewRender.Schema.PromptBuilder

  @spec to_json_schema(module()) :: map()
  def to_json_schema(catalog_module) when is_atom(catalog_module) do
    JSONSchemaBuilder.build(catalog_module)
  end

  @spec to_prompt(module()) :: String.t()
  def to_prompt(catalog_module) when is_atom(catalog_module) do
    PromptBuilder.build(catalog_module)
  end
end
