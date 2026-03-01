defmodule JsonLiveviewRender.Stream do
  @moduledoc """
  Structured event stream accumulator for incremental spec assembly.

  API scope:

  - Stability: v0.3 candidate (locked for this release cycle)
  - In v0.2 contract: Not required
  - Compatibility: Optional opt-in streaming surface for incremental rendering workflows

  ## Stream contract

  Streaming events use a three-state transition model over the same accumulator:

  1. `{:root, id}` establishes the root element id (idempotent when the same id is repeated).
  2. `{:element, id, element}` adds a new element after a root is known.
  3. `{:finalize}` marks the stream as complete.

  Allowed transitions and malformed-sequence handling:

  - `{:root, id}`:
    - accepted when no root is set
    - accepted again when the same root is repeated (idempotent)
    - rejected when a different root is set: `{:error, {:root_already_set, existing, incoming}}`
  - `{:element, id, element}`:
    - accepted when root has been established and the id is new
    - rejected when root is missing: `{:error, :root_not_set}`
    - rejected when element id already exists: `{:error, {:element_already_exists, id}}`
  - `{:finalize}`:
    - accepted after a root has been established
    - accepted again when already complete (`{:ok, stream}`).

  Invalid event shapes return `{:error, {:invalid_stream_event, event}}`.
  Once complete, all non-`:finalize` events return `{:error, :stream_already_finalized}`.
  """

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Spec.Normalizer

  @type event :: {:root, String.t()} | {:element, String.t(), map()} | {:finalize}
  @type transition_error ::
          :root_not_set
          | :stream_already_finalized
          | {:root_already_set, String.t(), String.t()}
          | {:element_already_exists, String.t()}
          | {:invalid_stream_event, term()}
  @type t :: %{
          root: String.t() | nil,
          elements: %{optional(String.t()) => map()},
          complete?: boolean()
        }

  @doc """
  Returns an empty stream accumulator.

  ## Examples

      iex> JsonLiveviewRender.Stream.new()
      %{root: nil, elements: %{}, complete?: false}
  """
  @spec new() :: t()
  def new, do: %{root: nil, elements: %{}, complete?: false}

  @doc """
  Applies a single stream event to the accumulator.

  Events are validated against the catalog before being accepted.
  See the module doc for the full transition contract.

  ## Examples

      iex> defmodule DocTestCatalog.StreamIngest do
      ...>   use JsonLiveviewRender.Catalog, include_primitives: false
      ...>   component :metric do
      ...>     description "KPI"
      ...>     prop :label, :string, required: true
      ...>     prop :value, :string, required: true
      ...>   end
      ...> end
      iex> stream = JsonLiveviewRender.Stream.new()
      iex> {:ok, stream} = JsonLiveviewRender.Stream.ingest(stream, {:root, "m1"}, DocTestCatalog.StreamIngest)
      iex> {:ok, stream} = JsonLiveviewRender.Stream.ingest(stream, {:element, "m1", %{"type" => "metric", "props" => %{"label" => "A", "value" => "1"}}}, DocTestCatalog.StreamIngest)
      iex> stream.root
      "m1"
      iex> Map.has_key?(stream.elements, "m1")
      true
  """
  @spec ingest(t(), event(), module(), keyword()) :: {:ok, t()} | {:error, term()}
  def ingest(stream, event, catalog, opts \\ []),
    do: process_transition(stream, event, catalog, opts)

  defp process_transition(%{complete?: true} = stream, {:finalize}, _catalog, _opts),
    do: {:ok, stream}

  defp process_transition(%{complete?: true}, _event, _catalog, _opts),
    do: {:error, :stream_already_finalized}

  defp process_transition(
         %{root: nil},
         {:element, id, element},
         _catalog,
         _opts
       )
       when is_binary(id) and is_map(element) do
    {:error, :root_not_set}
  end

  defp process_transition(
         %{elements: elements} = stream,
         {:element, id, element},
         catalog,
         opts
       )
       when is_binary(id) and is_map(element) do
    if Map.has_key?(elements, id) do
      {:error, {:element_already_exists, id}}
    else
      strict? = Keyword.get(opts, :strict, true)
      normalized = Normalizer.normalize_element(element)

      case Spec.validate_element(id, normalized, catalog, strict: strict?) do
        :ok ->
          {:ok, put_in(stream, [:elements, id], normalized)}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp process_transition(%{root: nil} = stream, {:root, id}, _catalog, _opts)
       when is_binary(id),
       do: {:ok, %{stream | root: id}}

  defp process_transition(%{root: existing} = stream, {:root, incoming}, _catalog, _opts)
       when is_binary(incoming) do
    if existing == incoming do
      {:ok, stream}
    else
      {:error, {:root_already_set, existing, incoming}}
    end
  end

  defp process_transition(%{root: nil}, {:finalize}, _catalog, _opts),
    do: {:error, :root_not_set}

  defp process_transition(stream, {:finalize}, _catalog, _opts),
    do: {:ok, %{stream | complete?: true}}

  defp process_transition(_stream, event, _catalog, _opts),
    do: {:error, {:invalid_stream_event, event}}

  @doc "Applies a list of events in order, halting on the first error."
  @spec ingest_many(t(), [event()], module(), keyword()) :: {:ok, t()} | {:error, term(), t()}
  def ingest_many(stream, events, catalog, opts \\ []) when is_list(events) and is_list(opts) do
    Enum.reduce_while(events, {:ok, stream}, fn event, {:ok, acc} ->
      case ingest(acc, event, catalog, opts) do
        {:ok, next} -> {:cont, {:ok, next}}
        {:error, reason} -> {:halt, {:error, reason, acc}}
      end
    end)
  end

  @doc """
  Validates the final assembled spec once streaming is complete.
  """
  @spec finalize(t(), module(), keyword()) :: {:ok, map()} | {:error, term()}
  def finalize(stream, catalog, opts \\ []) do
    require_complete? = Keyword.get(opts, :require_complete, true)
    strict? = Keyword.get(opts, :strict, true)

    cond do
      require_complete? and not stream.complete? ->
        {:error, :stream_not_finalized}

      stream.complete? ->
        Spec.validate(to_spec(stream), catalog, strict: strict?)

      true ->
        Spec.validate_partial(to_spec(stream), catalog, strict: strict?)
    end
  end

  @doc "Converts the accumulated stream state into a spec map."
  @spec to_spec(t()) :: map()
  def to_spec(stream) do
    %{"root" => stream.root, "elements" => stream.elements}
  end
end
