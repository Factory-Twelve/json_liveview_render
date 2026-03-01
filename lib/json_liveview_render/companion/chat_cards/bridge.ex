defmodule JsonLiveviewRender.Companion.ChatCards.Bridge do
  @moduledoc """
  Internal bridge that converts a filtered GenUI spec into the companion card IR.
  """

  alias JsonLiveviewRender.Companion.ChatCards.IR
  alias JsonLiveviewRender.Companion.ChatCards.Warnings

  @known_types MapSet.new([
                 "card",
                 "section",
                 "row",
                 "column",
                 "grid",
                 "card_list",
                 "status_badge",
                 "text",
                 "data_row",
                 "alert",
                 "metric",
                 "actions",
                 "button",
                 "data_table"
               ])

  @doc false
  @spec to_ir(map()) :: {:ok, IR.t(), [Warnings.t()]} | {:error, term()}
  def to_ir(spec), do: to_ir(spec, [])

  @doc false
  @spec to_ir(map(), keyword()) :: {:ok, IR.t(), [Warnings.t()]} | {:error, term()}
  def to_ir(%{"root" => root, "elements" => elements} = filtered_spec, _opts)
      when is_binary(root) and is_map(elements) do
    ir = IR.new(root, filtered_spec)
    {next_ir, warnings} = walk(root, elements, [], ir, [])
    {:ok, finalize(next_ir), Enum.reverse(warnings)}
  end

  def to_ir(_spec, _opts), do: {:error, :invalid_filtered_spec}

  defp walk(id, elements, path, ir, warnings) do
    node_path = path ++ [id]

    case Map.get(elements, id) do
      %{} = element ->
        {updated_ir, updated_warnings} = apply_element(id, element, node_path, ir, warnings)

        children = Map.get(element, "children", [])

        Enum.reduce(children, {updated_ir, updated_warnings}, fn child_id,
                                                                 {acc_ir, acc_warnings} ->
          walk(child_id, elements, node_path, acc_ir, acc_warnings)
        end)

      nil ->
        warning = Warnings.new(:missing_element, :bridge, node_path, "element not found", %{})
        {ir, [warning | warnings]}
    end
  end

  defp apply_element(id, %{"type" => type} = element, path, ir, warnings) do
    props = Map.get(element, "props", %{})
    type_text = to_string(type)

    cond do
      not MapSet.member?(@known_types, type_text) and Map.get(element, "children", []) != [] ->
        warning =
          Warnings.new(
            :unknown_container_type,
            :bridge,
            path,
            "unmapped container type #{inspect(type_text)} flattened",
            %{}
          )

        line = fallback_line(type_text, props)
        {append_body(ir, line), [warning | warnings]}

      not MapSet.member?(@known_types, type_text) ->
        warning =
          Warnings.new(
            :unknown_leaf_type,
            :bridge,
            path,
            "unmapped leaf type #{inspect(type_text)} rendered as text fallback",
            %{}
          )

        line = fallback_line(type_text, props)
        {append_body(ir, line), [warning | warnings]}

      type_text in ["card", "section", "card_list"] ->
        {set_title(ir, title_from_props(props)), warnings}

      type_text == "status_badge" ->
        severity = get_prop(props, ["severity", "status", "level"])
        label = get_prop(props, ["label", "message"])
        updated = ir |> set_severity(severity) |> append_body(label)
        {updated, warnings}

      type_text == "alert" ->
        title = title_from_props(props)
        severity = get_prop(props, ["severity", "status", "level"])
        message = get_prop(props, ["message", "content", "text"])
        updated = ir |> set_title(title) |> set_severity(severity) |> append_body(message)
        {updated, warnings}

      type_text == "text" ->
        line = get_prop(props, ["content", "text", "message"])
        {append_body(ir, line), warnings}

      type_text == "data_row" ->
        label = get_prop(props, ["label"])
        value = get_prop(props, ["value"])
        {append_fact(ir, label, value), warnings}

      type_text == "metric" ->
        label = get_prop(props, ["label"])
        value = get_prop(props, ["value"])
        {append_fact(ir, label, value), warnings}

      type_text == "data_table" ->
        columns = get_prop(props, ["columns"])
        rows = get_prop(props, ["rows_binding", "rows"])
        line = "Table: #{columns} / #{rows}"
        {append_body(ir, line), warnings}

      type_text == "button" ->
        action_id = get_prop(props, ["id", "action_id"]) |> fallback_blank(id)
        label = get_prop(props, ["label", "title"]) |> fallback_blank(action_id)

        action = %{
          action_id: action_id,
          label: label,
          style: normalize_style(get_prop(props, ["style"])),
          metadata: %{element_id: id, path: path}
        }

        {Map.update!(ir, :actions, &(&1 ++ [action])), warnings}

      true ->
        {ir, warnings}
    end
  end

  defp finalize(ir) do
    title =
      case ir.title do
        nil -> ir.card_id
        "" -> ir.card_id
        title -> title
      end

    %{ir | title: title}
  end

  defp set_title(ir, nil), do: ir
  defp set_title(ir, ""), do: ir

  defp set_title(ir, title) do
    cond do
      ir.title in [nil, "", ir.card_id] -> %{ir | title: title}
      true -> ir
    end
  end

  defp set_severity(ir, nil), do: ir
  defp set_severity(ir, ""), do: ir
  defp set_severity(ir, severity), do: %{ir | severity: String.downcase(severity)}

  defp append_body(ir, nil), do: ir
  defp append_body(ir, ""), do: ir
  defp append_body(ir, line), do: Map.update!(ir, :body_lines, &(&1 ++ [line]))

  defp append_fact(ir, nil, _), do: ir
  defp append_fact(ir, _, nil), do: ir

  defp append_fact(ir, label, value) do
    Map.update!(ir, :facts, &(&1 ++ [%{label: label, value: value}]))
  end

  defp title_from_props(props), do: get_prop(props, ["title", "label", "message"])

  defp get_prop(props, keys) do
    Enum.find_value(keys, fn key ->
      props
      |> Map.get(key)
      |> normalize_prop_value()
      |> case do
        nil -> nil
        "" -> nil
        value -> value
      end
    end)
  end

  defp normalize_prop_value(value) when is_binary(value), do: value
  defp normalize_prop_value(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_prop_value(value) when is_number(value), do: to_string(value)

  defp normalize_prop_value(value) when is_list(value) do
    value
    |> Enum.map(&normalize_prop_value/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp normalize_prop_value(value) when is_map(value), do: inspect(value)
  defp normalize_prop_value(_), do: nil

  defp fallback_line(type_text, props) do
    details = get_prop(props, ["title", "label", "message", "content", "text", "value"])

    case details do
      nil -> "[#{type_text}]"
      "" -> "[#{type_text}]"
      text -> "[#{type_text}] #{text}"
    end
  end

  defp fallback_blank(nil, fallback), do: fallback
  defp fallback_blank("", fallback), do: fallback
  defp fallback_blank(value, _fallback), do: value

  defp normalize_style(nil), do: "default"

  defp normalize_style(style) do
    case String.downcase(to_string(style)) do
      "danger" -> "danger"
      "destructive" -> "danger"
      "primary" -> "primary"
      "positive" -> "primary"
      _ -> "default"
    end
  end
end
