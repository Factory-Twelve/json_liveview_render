defmodule JsonLiveviewRender.Wire.MergePatch do
  @moduledoc """
  Applies JSON Merge Patch semantics to canonical `root + elements` specs.

  This module implements coarse object merge behavior against canonical specs:

  - omitted keys leave existing values unchanged
  - `nil` removes object members
  - object values merge by key
  - arrays replace atomically; there is no element-wise merge inside `children`

  Use `apply_and_validate/4` to revalidate the patched document through the
  existing canonical spec validation seam.
  """

  import Kernel, except: [apply: 2]

  alias JsonLiveviewRender.Spec
  alias JsonLiveviewRender.Spec.Normalize
  alias JsonLiveviewRender.Spec.Normalizer

  @type result :: {:ok, map()} | {:error, [term()]}
  @type validation_mode :: :complete | :partial

  @doc """
  Applies a merge patch to a canonical spec and returns the patched document.

  The base spec is canonicalized before patching so callers operate against a
  deterministic `root + elements` map. Patch maps use JSON object semantics, so
  object keys are stringified while scalar values are preserved for downstream
  validation.
  """
  @spec apply(map() | String.t(), map() | String.t()) :: result()
  def apply(spec, patch) do
    with {:ok, canonical_spec} <- Normalize.canonical(spec),
         {:ok, normalized_patch} <- normalize_patch(patch) do
      {:ok, merge_patch(canonical_spec, normalized_patch)}
    end
  end

  @doc """
  Applies a merge patch and validates the resulting document.

  Options:

  - `:validation` - `:complete` (default) or `:partial`
  - any remaining options are forwarded to `JsonLiveviewRender.Spec`
  """
  @spec apply_and_validate(map() | String.t(), map() | String.t(), module(), keyword()) ::
          result()
  def apply_and_validate(spec, patch, catalog, opts \\ []) when is_list(opts) do
    validation_mode = Keyword.get(opts, :validation, :complete)
    validation_opts = Keyword.drop(opts, [:validation])

    with :ok <- validate_validation_mode(validation_mode),
         {:ok, patched_spec} <- apply(spec, patch) do
      validate_patched_spec(patched_spec, catalog, validation_mode, validation_opts)
    end
  end

  defp validate_validation_mode(:complete), do: :ok
  defp validate_validation_mode(:partial), do: :ok

  defp validate_validation_mode(_mode) do
    {:error, [{:invalid_validation_mode, "validation must be :complete or :partial"}]}
  end

  defp validate_patched_spec(spec, catalog, :complete, opts),
    do: Spec.validate(spec, catalog, opts)

  defp validate_patched_spec(spec, catalog, :partial, opts),
    do: Spec.validate_partial(spec, catalog, opts)

  defp normalize_patch(patch) when is_map(patch), do: {:ok, normalize_patch_value(patch)}

  defp normalize_patch(patch) when is_binary(patch) do
    with {:ok, decoded} <- Jason.decode(patch),
         {:ok, object_patch} <- ensure_object_patch(decoded) do
      {:ok, normalize_patch_value(object_patch)}
    else
      {:error, %Jason.DecodeError{} = reason} -> {:error, [{:invalid_json_patch, reason}]}
      {:error, reasons} -> {:error, reasons}
    end
  end

  defp normalize_patch(_patch),
    do: {:error, [{:invalid_patch, "merge patch must be a map or JSON object"}]}

  defp ensure_object_patch(patch) when is_map(patch), do: {:ok, patch}

  defp ensure_object_patch(_patch),
    do: {:error, [{:invalid_patch, "merge patch must be a JSON object"}]}

  defp normalize_patch_value(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {Normalizer.safe_to_string(key), normalize_patch_value(nested_value)}
    end)
  end

  defp normalize_patch_value(value) when is_list(value) do
    Enum.map(value, &normalize_patch_value/1)
  end

  defp normalize_patch_value(value), do: value

  # RFC 7386 semantics: object patches merge by key, and arrays replace
  # atomically because any non-object patch value replaces the prior value.
  defp merge_patch(target, patch) when is_map(patch) do
    target_map = if is_map(target), do: target, else: %{}

    Enum.reduce(patch, target_map, fn
      {key, nil}, acc ->
        Map.delete(acc, key)

      {key, value}, acc ->
        Map.put(acc, key, merge_patch(Map.get(acc, key), value))
    end)
  end

  defp merge_patch(_target, patch), do: patch
end
