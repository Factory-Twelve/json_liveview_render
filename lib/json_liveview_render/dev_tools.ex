defmodule JsonLiveviewRender.DevTools do
  @moduledoc """
  Experimental development utility.

  API scope:

  - Stability: experimental / deferred
  - Not part of the v0.3 core scope lock

  Development inspector for rendered JsonLiveviewRender specs.

  Use this from `JsonLiveviewRender.Renderer` with `dev_tools: true`
  to inspect input/rendered specs directly in browser output.
  """

  use Phoenix.Component

  alias JsonLiveviewRender.Spec

  attr(:input_spec, :map, required: true)
  attr(:render_spec, :map, required: true)
  attr(:catalog, :any, required: true)
  attr(:strict, :boolean, default: true)
  attr(:allow_partial, :boolean, default: false)
  attr(:open, :boolean, default: false)
  attr(:label, :string, default: "JsonLiveviewRender DevTools")

  def render(assigns) do
    input_report =
      inspect_spec(assigns.input_spec, assigns.catalog, assigns.strict, assigns.allow_partial)

    render_report =
      inspect_spec(assigns.render_spec, assigns.catalog, assigns.strict, assigns.allow_partial)

    assigns =
      assigns
      |> assign(:input_report, input_report)
      |> assign(:render_report, render_report)
      |> assign(:input_json, pretty_json(assigns.input_spec))
      |> assign(:render_json, pretty_json(assigns.render_spec))

    ~H"""
    <details data-json-liveview-render-devtools open={@open}>
      <summary>
        <%= @label %>
        [root=<%= @render_report.root || "nil" %>, elements=<%= @render_report.element_count %>]
      </summary>

      <div data-json-liveview-render-devtools-content>
        <p>
          input_status=<%= @input_report.status %>,
          render_status=<%= @render_report.status %>
        </p>

        <h4>Input Spec</h4>
        <pre data-json-liveview-render-input-spec><%= @input_json %></pre>

        <%= if @input_report.errors != [] do %>
          <h5>Input Errors</h5>
          <pre data-json-liveview-render-input-errors><%= inspect(@input_report.errors, pretty: true) %></pre>
        <% end %>

        <h4>Rendered Spec</h4>
        <pre data-json-liveview-render-render-spec><%= @render_json %></pre>

        <%= if @render_report.errors != [] do %>
          <h5>Rendered Errors</h5>
          <pre data-json-liveview-render-render-errors><%= inspect(@render_report.errors, pretty: true) %></pre>
        <% end %>
      </div>
    </details>
    """
  end

  defp inspect_spec(spec, catalog, strict?, allow_partial?) do
    validator = if allow_partial?, do: &Spec.validate_partial/3, else: &Spec.validate/3
    result = validator.(spec, catalog, strict: strict?)

    case result do
      {:ok, %{"root" => root, "elements" => elements}} ->
        %{status: :ok, root: root, element_count: map_size(elements), errors: []}

      {:error, reasons} when is_list(reasons) ->
        %{
          status: :error,
          root: root_of(spec),
          element_count: element_count(spec),
          errors: reasons
        }
    end
  end

  defp root_of(%{"root" => root}), do: root
  defp root_of(%{root: root}), do: root
  defp root_of(_), do: nil

  defp element_count(%{"elements" => elements}) when is_map(elements), do: map_size(elements)
  defp element_count(%{elements: elements}) when is_map(elements), do: map_size(elements)
  defp element_count(_), do: 0

  defp pretty_json(map) when is_map(map) do
    map
    |> Jason.encode_to_iodata!(pretty: true)
    |> IO.iodata_to_binary()
  end
end
