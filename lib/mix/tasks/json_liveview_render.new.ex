defmodule Mix.Tasks.JsonLiveviewRender.New do
  use Mix.Task

  @shortdoc "Generates JsonLiveviewRender starter files (catalog, components, registry, authorizer, spec)"
  @moduledoc """
  Generates starter JsonLiveviewRender files in a target project directory.

  ## Usage

      mix json_liveview_render.new
      mix json_liveview_render.new /path/to/project
      mix json_liveview_render.new --module MyApp
      mix json_liveview_render.new /path/to/project --module MyCompany.App --force

  By default, this creates:

  - `lib/<module_path>/json_liveview_render/catalog.ex`
  - `lib/<module_path>/json_liveview_render/components.ex`
  - `lib/<module_path>/json_liveview_render/registry.ex`
  - `lib/<module_path>/json_liveview_render/authorizer.ex`
  - `priv/json_liveview_render/example_spec.json`
  """

  @switches [module: :string, force: :boolean]
  @aliases [m: :module, f: :force]

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} =
      OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if invalid != [] do
      Mix.raise("invalid options: #{inspect(invalid)}")
    end

    target_dir =
      case positional do
        [] -> File.cwd!()
        [path] -> Path.expand(path)
        _ -> Mix.raise("expected zero or one path argument")
      end

    module_base = opts[:module] || infer_module_base(target_dir)
    validate_module_base!(module_base)

    files = scaffold_files(module_base)
    force? = Keyword.get(opts, :force, false)

    Enum.each(files, fn {relative_path, contents} ->
      write_file!(target_dir, relative_path, contents, force?)
    end)

    Mix.shell().info("")
    Mix.shell().info("JsonLiveviewRender starter files generated for #{module_base}.")
    Mix.shell().info("Next step: wire registry callbacks to your real component modules.")
  end

  defp write_file!(target_dir, relative_path, contents, force?) do
    path = Path.join(target_dir, relative_path)
    File.mkdir_p!(Path.dirname(path))

    cond do
      File.exists?(path) and not force? ->
        Mix.raise(
          "refusing to overwrite #{relative_path}; pass --force to replace existing files"
        )

      File.exists?(path) and force? ->
        Mix.shell().info("* overwriting #{relative_path}")
        File.write!(path, contents)

      true ->
        Mix.shell().info("* creating #{relative_path}")
        File.write!(path, contents)
    end
  end

  defp infer_module_base(target_dir) do
    app = Mix.Project.config()[:app]

    cond do
      is_atom(app) and Path.expand(File.cwd!()) == Path.expand(target_dir) ->
        app |> Atom.to_string() |> Macro.camelize()

      true ->
        target_dir
        |> Path.basename()
        |> sanitize_name()
        |> Macro.camelize()
    end
  end

  defp sanitize_name(name) do
    name
    |> String.replace(~r/[^a-zA-Z0-9_]/, "_")
    |> String.trim("_")
    |> case do
      "" -> "my_app"
      sanitized -> sanitized
    end
  end

  defp validate_module_base!(module_base) do
    if module_base =~ ~r/^[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)*$/ do
      :ok
    else
      Mix.raise(
        "invalid --module #{inspect(module_base)}. Expected CamelCase module name, e.g. MyApp or MyCompany.App"
      )
    end
  end

  defp scaffold_files(module_base) do
    module_path = Macro.underscore(module_base)
    catalog_module = "#{module_base}.JsonLiveviewRender.Catalog"
    components_module = "#{module_base}.JsonLiveviewRender.Components"
    registry_module = "#{module_base}.JsonLiveviewRender.Registry"
    authorizer_module = "#{module_base}.JsonLiveviewRender.Authorizer"
    json_liveview_render_dir = Path.join(["lib", module_path, "json_liveview_render"])

    %{
      Path.join(json_liveview_render_dir, "catalog.ex") => catalog_template(catalog_module),
      Path.join(json_liveview_render_dir, "components.ex") =>
        components_template(components_module),
      Path.join(json_liveview_render_dir, "registry.ex") =>
        registry_template(registry_module, catalog_module, components_module),
      Path.join(json_liveview_render_dir, "authorizer.ex") =>
        authorizer_template(authorizer_module),
      Path.join("priv/json_liveview_render", "example_spec.json") => spec_template()
    }
  end

  defp catalog_template(catalog_module) do
    """
    defmodule #{catalog_module} do
      use JsonLiveviewRender.Catalog

      component :metric do
        description("Single KPI metric")
        prop(:label, :string, required: true)
        prop(:value, :string, required: true)
        prop(:trend, :enum, values: [:up, :down, :flat])
      end
    end
    """
  end

  defp components_template(components_module) do
    """
    defmodule #{components_module} do
      use Phoenix.Component

      attr(:label, :string, required: true)
      attr(:value, :string, required: true)
      attr(:trend, :string, default: nil)
      def metric(assigns) do
        ~H\"\"\"
        <div class="metric">
          <span class="label"><%= @label %></span>
          <span class="value"><%= @value %></span>
          <span :if={@trend} class="trend"><%= @trend %></span>
        </div>
        \"\"\"
      end

      attr(:children, :list, default: [])
      def row(assigns) do
        ~H\"\"\"
        <div class="row">
          <%= for child <- @children do %>
            <%= child %>
          <% end %>
        </div>
        \"\"\"
      end

      attr(:children, :list, default: [])
      def column(assigns) do
        ~H\"\"\"
        <div class="column">
          <%= for child <- @children do %>
            <%= child %>
          <% end %>
        </div>
        \"\"\"
      end

      attr(:children, :list, default: [])
      def section(assigns) do
        ~H\"\"\"
        <section>
          <%= for child <- @children do %>
            <%= child %>
          <% end %>
        </section>
        \"\"\"
      end

      attr(:children, :list, default: [])
      def grid(assigns) do
        ~H\"\"\"
        <div class="grid">
          <%= for child <- @children do %>
            <%= child %>
          <% end %>
        </div>
        \"\"\"
      end
    end
    """
  end

  defp registry_template(registry_module, catalog_module, components_module) do
    """
    defmodule #{registry_module} do
      use JsonLiveviewRender.Registry, catalog: #{catalog_module}

      alias #{components_module}

      render(:metric, &Components.metric/1)
      render(:row, &Components.row/1)
      render(:column, &Components.column/1)
      render(:section, &Components.section/1)
      render(:grid, &Components.grid/1)
    end
    """
  end

  defp authorizer_template(authorizer_module) do
    """
    defmodule #{authorizer_module} do
      @behaviour JsonLiveviewRender.Authorizer

      @impl true
      def allowed?(_current_user, _required_role), do: true
    end
    """
  end

  defp spec_template do
    """
    {
      "root": "root",
      "elements": {
        "root": {
          "type": "row",
          "props": {},
          "children": ["metric_1"]
        },
        "metric_1": {
          "type": "metric",
          "props": {
            "label": "Revenue",
            "value": "$42k",
            "trend": "up"
          },
          "children": []
        }
      }
    }
    """
  end
end
