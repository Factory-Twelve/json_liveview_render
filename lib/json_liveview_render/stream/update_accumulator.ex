defmodule JsonLiveviewRender.Stream.UpdateAccumulator do
  @moduledoc false

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Spec.Normalizer

  @type sequence :: pos_integer()
  @type t :: %__MODULE__{
          spec: map(),
          complete?: boolean(),
          last_sequence: sequence() | nil,
          applied_updates: %{optional(sequence()) => map()}
        }

  defstruct spec: %{"root" => nil, "elements" => %{}},
            complete?: false,
            last_sequence: nil,
            applied_updates: %{}

  @spec from_stream(map()) :: t()
  def from_stream(%{root: root, elements: elements, complete?: complete?}) do
    %__MODULE__{
      spec: %{"root" => root, "elements" => elements},
      complete?: complete?
    }
  end

  @spec sync(t(), map()) :: t()
  def sync(%__MODULE__{} = accumulator, %{root: root, elements: elements, complete?: complete?}) do
    %{accumulator | spec: %{"root" => root, "elements" => elements}, complete?: complete?}
  end

  @spec apply(t(), map(), module(), keyword()) :: {:ok, t()} | {:error, term()}
  def apply(%__MODULE__{} = accumulator, update, catalog, opts \\ []) when is_list(opts) do
    strict? = Keyword.get(opts, :strict, true)

    with {:ok, normalized_update} <- normalize_update(update) do
      case replay_status(accumulator, normalized_update) do
        :duplicate ->
          {:ok, accumulator}

        :ok ->
          do_apply(accumulator, normalized_update, catalog, strict?)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp do_apply(accumulator, normalized_update, catalog, strict?) do
    with :ok <- ensure_open(accumulator),
         {:ok, next_spec} <- apply_root(accumulator.spec, normalized_update),
         {:ok, next_spec} <- apply_elements(next_spec, normalized_update, catalog, strict?),
         {:ok, next_complete?} <- apply_finalize(accumulator, normalized_update, next_spec) do
      {:ok,
       %{
         accumulator
         | spec: next_spec,
           complete?: next_complete?,
           last_sequence: normalized_update["sequence"],
           applied_updates:
             Map.put(
               accumulator.applied_updates,
               normalized_update["sequence"],
               normalized_update
             )
       }}
    end
  end

  defp replay_status(
         %__MODULE__{applied_updates: applied_updates, last_sequence: last_sequence},
         %{"sequence" => sequence} = normalized_update
       ) do
    case Map.fetch(applied_updates, sequence) do
      {:ok, ^normalized_update} ->
        :duplicate

      {:ok, _other_update} ->
        {:error, {:conflicting_update_sequence, sequence}}

      :error ->
        if not is_nil(last_sequence) and sequence <= last_sequence do
          {:error, {:out_of_order_update, last_sequence, sequence}}
        else
          :ok
        end
    end
  end

  defp ensure_open(%__MODULE__{complete?: true}), do: {:error, :stream_already_finalized}
  defp ensure_open(%__MODULE__{}), do: :ok

  defp apply_root(spec, %{"root" => incoming_root}) do
    case spec["root"] do
      nil ->
        {:ok, %{"root" => incoming_root, "elements" => spec["elements"]}}

      ^incoming_root ->
        {:ok, spec}

      existing_root ->
        {:error, {:root_already_set, existing_root, incoming_root}}
    end
  end

  defp apply_root(spec, _normalized_update), do: {:ok, spec}

  defp apply_elements(spec, %{"elements" => elements}, catalog, strict?) do
    elements
    |> Enum.sort_by(fn {id, _element} -> id end)
    |> Enum.reduce_while({:ok, spec["elements"]}, fn {id, element}, {:ok, acc} ->
      case validate_element_update(id, element, catalog, strict?) do
        :ok -> {:cont, {:ok, Map.put(acc, id, element)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, updated_elements} ->
        {:ok, %{"root" => spec["root"], "elements" => updated_elements}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp apply_elements(spec, _normalized_update, _catalog, _strict?), do: {:ok, spec}

  defp apply_finalize(_accumulator, %{"finalize" => true}, spec) do
    if is_nil(spec["root"]) do
      {:error, :root_not_set}
    else
      {:ok, true}
    end
  end

  defp apply_finalize(%__MODULE__{complete?: complete?}, _normalized_update, _spec),
    do: {:ok, complete?}

  defp validate_element_update(id, element, catalog, strict?) when is_map(element) do
    Spec.validate_element(id, element, catalog, strict: strict?)
  end

  defp validate_element_update(id, _element, _catalog, _strict?),
    do: {:error, {:invalid_update_element, id}}

  defp normalize_update(update) when is_map(update) do
    with {:ok, sequence} <- normalize_sequence(update),
         {:ok, root} <- normalize_optional_root(update),
         {:ok, elements} <- normalize_optional_elements(update),
         {:ok, finalize?} <- normalize_finalize(update) do
      normalized_update =
        %{"sequence" => sequence}
        |> maybe_put_root(root)
        |> maybe_put_elements(elements)
        |> maybe_put_finalize(finalize?)

      if map_size(normalized_update) == 1 do
        {:error, {:invalid_update, "update must include root, elements, or finalize"}}
      else
        {:ok, normalized_update}
      end
    end
  end

  defp normalize_update(update), do: {:error, {:invalid_update, update}}

  defp normalize_sequence(update) do
    case fetch_optional(update, :sequence, "sequence") do
      {:present, sequence} when is_integer(sequence) and sequence > 0 ->
        {:ok, sequence}

      _other ->
        {:error, {:invalid_update_sequence, "sequence must be a positive integer"}}
    end
  end

  defp normalize_optional_root(update) do
    case fetch_optional(update, :root, "root") do
      :absent ->
        {:ok, :absent}

      {:present, nil} ->
        {:error, {:invalid_update_root, "root must be a string when present"}}

      {:present, root} ->
        {:ok, Normalizer.safe_to_string(root)}
    end
  end

  defp normalize_optional_elements(update) do
    case fetch_optional(update, :elements, "elements") do
      :absent ->
        {:ok, :absent}

      {:present, elements} when is_map(elements) ->
        {:ok,
         Map.new(elements, fn {id, element} ->
           {Normalizer.safe_to_string(id), normalize_element_update(element)}
         end)}

      {:present, _elements} ->
        {:error, {:invalid_update_elements, "elements must be a map when present"}}
    end
  end

  defp normalize_finalize(update) do
    case fetch_optional(update, :finalize, "finalize") do
      :absent ->
        {:ok, false}

      {:present, finalize?} when is_boolean(finalize?) ->
        {:ok, finalize?}

      {:present, _finalize} ->
        {:error, {:invalid_update_finalize, "finalize must be boolean when present"}}
    end
  end

  defp normalize_element_update(element) when is_map(element),
    do: Normalizer.normalize_element(element)

  defp normalize_element_update(element), do: element

  defp maybe_put_root(update, :absent), do: update
  defp maybe_put_root(update, root), do: Map.put(update, "root", root)

  defp maybe_put_elements(update, :absent), do: update
  defp maybe_put_elements(update, elements), do: Map.put(update, "elements", elements)

  defp maybe_put_finalize(update, false), do: update
  defp maybe_put_finalize(update, true), do: Map.put(update, "finalize", true)

  defp fetch_optional(map, atom_key, string_key) do
    cond do
      Map.has_key?(map, atom_key) -> {:present, Map.get(map, atom_key)}
      Map.has_key?(map, string_key) -> {:present, Map.get(map, string_key)}
      true -> :absent
    end
  end
end
