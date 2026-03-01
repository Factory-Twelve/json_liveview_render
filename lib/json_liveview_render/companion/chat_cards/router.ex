defmodule JsonLiveviewRender.Companion.ChatCards.Router do
  @moduledoc """
  Internal orchestration pipeline for companion chat-card compilation and optional delivery.
  """

  alias JsonLiveviewRender.Companion.ChatCards.Bridge
  alias JsonLiveviewRender.Companion.ChatCards.Target
  alias JsonLiveviewRender.Companion.ChatCards.Warnings
  alias JsonLiveviewRender.Permissions
  alias JsonLiveviewRender.Spec

  @typedoc false
  @type compile_result :: %{
          required(:filtered_spec) => map(),
          required(:outputs) => %{optional(Target.t()) => map()},
          required(:actions) => [map()],
          required(:warnings) => [Warnings.t()],
          required(:deliveries) => %{optional(Target.t()) => {:ok, term()} | {:error, term()}}
        }

  @doc false
  @spec compile(map() | String.t(), keyword()) :: {:ok, compile_result()} | {:error, term()}
  def compile(spec, opts) do
    with {:ok, config} <- normalize_opts(opts),
         {:ok, validated_spec} <- Spec.validate(spec, config.catalog, strict: config.strict) do
      filtered_spec =
        Permissions.filter(
          validated_spec,
          config.current_user,
          config.catalog,
          config.authorizer
        )

      with {:ok, ir, bridge_warnings} <- Bridge.to_ir(filtered_spec),
           {:ok, outputs, target_warnings, action_envelopes} <-
             render_targets(config.targets, ir, config) do
        {:ok,
         %{
           filtered_spec: filtered_spec,
           outputs: outputs,
           actions: action_envelopes,
           warnings: bridge_warnings ++ target_warnings,
           deliveries: %{}
         }}
      end
    end
  end

  @doc false
  @spec compile_and_send(map() | String.t(), keyword()) ::
          {:ok, compile_result()} | {:error, term()}
  def compile_and_send(spec, opts) do
    with {:ok, sender} <- fetch_sender(opts),
         {:ok, result} <- compile(spec, opts) do
      if is_nil(sender) do
        {:ok, result}
      else
        context = Keyword.get(opts, :context, %{})
        {deliveries, delivery_warnings} = deliver_outputs(sender, result.outputs, context)

        {:ok, %{result | deliveries: deliveries, warnings: result.warnings ++ delivery_warnings}}
      end
    end
  end

  defp normalize_opts(opts) do
    with {:ok, catalog} <- fetch_required_opt(opts, :catalog),
         {:ok, current_user} <- fetch_required_opt(opts, :current_user),
         {:ok, targets} <-
           normalize_targets(Keyword.get(opts, :targets, Target.default_targets())) do
      {:ok,
       %{
         catalog: catalog,
         current_user: current_user,
         strict: Keyword.get(opts, :strict, true),
         authorizer: Keyword.get(opts, :authorizer, JsonLiveviewRender.Authorizer.AllowAll),
         targets: targets,
         slack_surface: Keyword.get(opts, :slack_surface, :message),
         whatsapp_mode: Keyword.get(opts, :whatsapp_mode, :auto),
         context: Keyword.get(opts, :context, %{})
       }}
    end
  end

  defp fetch_required_opt(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_required_option, key}}
    end
  end

  defp normalize_targets(targets) when is_list(targets) do
    targets = Enum.uniq(targets)

    case Enum.find(targets, &(Target.module_for(&1) == :error)) do
      nil -> {:ok, targets}
      unknown -> {:error, {:unsupported_target, unknown}}
    end
  end

  defp normalize_targets(_), do: {:error, {:invalid_targets, :expected_list}}

  defp render_targets(targets, ir, config) do
    Enum.reduce_while(targets, {:ok, %{}, [], []}, fn target, {:ok, outputs, warnings, actions} ->
      with {:ok, module} <- Target.module_for(target),
           {:ok, payload, target_warnings, action_refs} <-
             module.render(ir,
               slack_surface: config.slack_surface,
               whatsapp_mode: config.whatsapp_mode,
               context: config.context,
               filtered_spec: ir.filtered_spec
             ) do
        target_actions =
          Enum.map(action_refs, fn action_ref ->
            %{
              version: "v1",
              action_id: action_ref.action_id,
              card_id: ir.card_id,
              source_platform: target,
              metadata: Map.get(action_ref, :metadata, %{})
            }
          end)

        {:cont,
         {:ok, Map.put(outputs, target, payload), warnings ++ target_warnings,
          actions ++ target_actions}}
      else
        :error ->
          {:halt, {:error, {:unsupported_target, target}}}

        {:error, reason} ->
          {:halt, {:error, {:target_render_failed, target, reason}}}
      end
    end)
  end

  defp fetch_sender(opts) do
    case Keyword.get(opts, :sender) do
      nil ->
        {:ok, nil}

      module when is_atom(module) ->
        if function_exported?(module, :deliver, 3) do
          {:ok, module}
        else
          {:error, :invalid_sender}
        end

      _ ->
        {:error, :invalid_sender}
    end
  end

  defp deliver_outputs(sender, outputs, context) do
    targets = Target.sendable_targets()

    Enum.reduce(targets, {%{}, []}, fn target, {deliveries, warnings} ->
      case Map.fetch(outputs, target) do
        {:ok, payload} ->
          case sender.deliver(target, payload, context) do
            {:ok, _} = ok ->
              {Map.put(deliveries, target, ok), warnings}

            {:error, reason} = error ->
              warning =
                Warnings.new(
                  :delivery_failed,
                  :delivery,
                  [Atom.to_string(target)],
                  "delivery failed for #{target}",
                  %{reason: inspect(reason)}
                )

              {Map.put(deliveries, target, error), warnings ++ [warning]}
          end

        :error ->
          {deliveries, warnings}
      end
    end)
  end
end
