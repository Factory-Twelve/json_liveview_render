defmodule JsonLiveviewRender.Stream do
  @moduledoc """
  Structured event stream accumulator for incremental spec assembly.

  API scope:

  - Stability: v0.3 candidate (locked for this release cycle)
  - In v0.2 contract: Not required
  - Compatibility: Optional opt-in streaming surface for incremental rendering workflows
  """

  alias JsonLiveviewRender.Spec

  @type event :: {:root, String.t()} | {:element, String.t(), map()} | {:finalize}
  @type t :: %{
          root: String.t() | nil,
          elements: %{optional(String.t()) => map()},
          complete?: boolean()
        }

  @spec new() :: t()
  def new, do: %{root: nil, elements: %{}, complete?: false}

  @spec ingest(t(), event(), module()) :: {:ok, t()} | {:error, term()}
  def ingest(stream, {:root, id}, _catalog) when is_binary(id), do: {:ok, %{stream | root: id}}

  def ingest(stream, {:element, id, element}, catalog) when is_binary(id) and is_map(element) do
    normalized = normalize_stream_element(element)

    case Spec.validate_element(id, normalized, catalog) do
      :ok -> {:ok, put_in(stream, [:elements, id], normalized)}
      {:error, reason} -> {:error, reason}
    end
  end

  def ingest(stream, {:finalize}, _catalog), do: {:ok, %{stream | complete?: true}}

  def ingest(_stream, event, _catalog), do: {:error, {:invalid_stream_event, event}}

  @spec to_spec(t()) :: map()
  def to_spec(stream) do
    %{"root" => stream.root, "elements" => stream.elements}
  end

  defp normalize_stream_element(element) do
    type = Map.get(element, "type") || Map.get(element, :type)
    props = Map.get(element, "props") || Map.get(element, :props) || %{}
    children = Map.get(element, "children") || Map.get(element, :children) || []

    %{
      "type" => if(is_atom(type), do: Atom.to_string(type), else: type),
      "props" => normalize_map_keys(props),
      "children" => Enum.map(children, &to_string/1)
    }
  end

  defp normalize_map_keys(map) when is_map(map),
    do: Map.new(map, fn {k, v} -> {to_string(k), v} end)
end
