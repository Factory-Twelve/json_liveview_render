defmodule JsonLiveviewRender.Companion.ChatCards.Platform.Limits do
  @moduledoc """
  Internal limit/truncation helpers for companion target payloads.
  """

  alias JsonLiveviewRender.Companion.ChatCards.Warnings

  @doc false
  @spec slack_surface_block_limit(atom()) :: pos_integer()
  def slack_surface_block_limit(:home), do: 100
  def slack_surface_block_limit(:modal), do: 100
  def slack_surface_block_limit(_), do: 50

  @doc false
  @spec slack_trim_blocks([map()], atom()) :: {[map()], [Warnings.t()]}
  def slack_trim_blocks(blocks, surface) when is_list(blocks) do
    max_blocks = slack_surface_block_limit(surface)

    {trimmed_blocks, warnings} =
      if length(blocks) > max_blocks do
        warning =
          Warnings.new(
            :slack_blocks_truncated,
            :slack,
            ["blocks"],
            "slack blocks trimmed to #{max_blocks}",
            %{surface: surface, kept: max_blocks, dropped: length(blocks) - max_blocks}
          )

        {Enum.take(blocks, max_blocks), [warning]}
      else
        {blocks, []}
      end

    Enum.reduce(trimmed_blocks, {[], warnings}, fn block, {acc, acc_warnings} ->
      {next_block, next_warnings} = slack_trim_block(block)
      {acc ++ [next_block], acc_warnings ++ next_warnings}
    end)
  end

  @doc false
  @spec whatsapp_mode(atom(), list()) :: :buttons | :list
  def whatsapp_mode(:buttons, _actions), do: :buttons
  def whatsapp_mode(:list, _actions), do: :list

  def whatsapp_mode(:auto, actions) when is_list(actions) do
    if length(actions) <= 3, do: :buttons, else: :list
  end

  def whatsapp_mode(_, actions) when is_list(actions) do
    if length(actions) <= 3, do: :buttons, else: :list
  end

  @doc false
  @spec whatsapp_trim_buttons([map()]) :: {[map()], [Warnings.t()]}
  def whatsapp_trim_buttons(actions) when is_list(actions) do
    {base_actions, warnings} =
      if length(actions) > 3 do
        warning =
          Warnings.new(
            :whatsapp_buttons_truncated,
            :whatsapp,
            ["interactive", "action", "buttons"],
            "whatsapp reply buttons trimmed to 3",
            %{kept: 3, dropped: length(actions) - 3}
          )

        {Enum.take(actions, 3), [warning]}
      else
        {actions, []}
      end

    Enum.reduce(base_actions, {[], warnings}, fn action, {acc, acc_warnings} ->
      {id, id_warnings} = truncate_text(action["id"] || "", 256, :whatsapp, ["id"])
      {label, label_warnings} = truncate_text(action["title"] || "", 20, :whatsapp, ["title"])

      next = %{"id" => id, "title" => label}
      {acc ++ [next], acc_warnings ++ id_warnings ++ label_warnings}
    end)
  end

  @doc false
  @spec whatsapp_trim_list_rows([map()]) :: {[map()], [Warnings.t()]}
  def whatsapp_trim_list_rows(actions) when is_list(actions) do
    {rows, warnings} =
      if length(actions) > 10 do
        warning =
          Warnings.new(
            :whatsapp_rows_truncated,
            :whatsapp,
            ["interactive", "action", "sections", "rows"],
            "whatsapp list rows trimmed to 10",
            %{kept: 10, dropped: length(actions) - 10}
          )

        {Enum.take(actions, 10), [warning]}
      else
        {actions, []}
      end

    Enum.reduce(rows, {[], warnings}, fn row, {acc, acc_warnings} ->
      {id, id_warnings} = truncate_text(row["id"] || "", 200, :whatsapp, ["id"])
      {title, title_warnings} = truncate_text(row["title"] || "", 24, :whatsapp, ["title"])

      {description, description_warnings} =
        truncate_text(row["description"] || "", 72, :whatsapp, ["description"])

      next = %{"id" => id, "title" => title, "description" => description}
      {acc ++ [next], acc_warnings ++ id_warnings ++ title_warnings ++ description_warnings}
    end)
  end

  @doc false
  @spec truncate_text(binary(), non_neg_integer(), atom(), [String.t()]) ::
          {binary(), [Warnings.t()]}
  def truncate_text(text, max, target, path) when is_binary(text) and is_integer(max) do
    if String.length(text) > max do
      warning =
        Warnings.new(
          :text_truncated,
          target,
          path,
          "text truncated to #{max} characters",
          %{max: max, original: String.length(text)}
        )

      {String.slice(text, 0, max), [warning]}
    else
      {text, []}
    end
  end

  defp slack_trim_block(%{"type" => "actions", "elements" => elements} = block)
       when is_list(elements) do
    {trimmed_elements, warnings} =
      if length(elements) > 25 do
        warning =
          Warnings.new(
            :slack_actions_truncated,
            :slack,
            ["actions", "elements"],
            "slack actions trimmed to 25 elements",
            %{kept: 25, dropped: length(elements) - 25}
          )

        {Enum.take(elements, 25), [warning]}
      else
        {elements, []}
      end

    Enum.reduce(trimmed_elements, {%{block | "elements" => []}, warnings}, fn element,
                                                                              {acc_block,
                                                                               acc_warnings} ->
      {next_element, next_warnings} = slack_trim_button(element)

      {%{acc_block | "elements" => acc_block["elements"] ++ [next_element]},
       acc_warnings ++ next_warnings}
    end)
  end

  defp slack_trim_block(block), do: {block, []}

  defp slack_trim_button(%{"type" => "button"} = button) do
    text = get_in(button, ["text", "text"]) || ""
    action_id = button["action_id"] || ""

    {trimmed_text, text_warnings} = truncate_text(text, 75, :slack, ["button", "text"])

    {trimmed_action_id, id_warnings} =
      truncate_text(action_id, 255, :slack, ["button", "action_id"])

    next =
      button
      |> put_in(["text", "text"], trimmed_text)
      |> Map.put("action_id", trimmed_action_id)

    {next, text_warnings ++ id_warnings}
  end

  defp slack_trim_button(element), do: {element, []}
end
