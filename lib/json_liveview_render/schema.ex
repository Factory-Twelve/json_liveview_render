defmodule JsonLiveviewRender.Schema do
  @moduledoc "Exports catalog metadata to JSON Schema and prompt-friendly text."

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
