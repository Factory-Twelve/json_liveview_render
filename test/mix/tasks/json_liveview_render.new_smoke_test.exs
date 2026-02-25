defmodule Mix.Tasks.JsonLiveviewRender.NewSmokeTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @task "json_liveview_render.new"

  setup do
    Mix.Task.reenable(@task)

    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "json_liveview_render_new_smoke_#{System.unique_integer([:positive, :monotonic])}"
      )

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "generated scaffold compiles and renders example spec", %{tmp_dir: tmp_dir} do
    module_base = "AcmeSmoke#{System.unique_integer([:positive, :monotonic])}"

    capture_io(fn ->
      Mix.Tasks.JsonLiveviewRender.New.run([tmp_dir, "--module", module_base])
    end)

    module_path = Macro.underscore(module_base)

    Enum.each(
      [
        Path.join(tmp_dir, "lib/#{module_path}/json_liveview_render/catalog.ex"),
        Path.join(tmp_dir, "lib/#{module_path}/json_liveview_render/components.ex"),
        Path.join(tmp_dir, "lib/#{module_path}/json_liveview_render/registry.ex"),
        Path.join(tmp_dir, "lib/#{module_path}/json_liveview_render/authorizer.ex")
      ],
      &Code.compile_file/1
    )

    catalog_module = Module.concat([module_base, "JsonLiveviewRender", "Catalog"])
    registry_module = Module.concat([module_base, "JsonLiveviewRender", "Registry"])
    authorizer_module = Module.concat([module_base, "JsonLiveviewRender", "Authorizer"])

    spec =
      tmp_dir
      |> Path.join("priv/json_liveview_render/example_spec.json")
      |> File.read!()
      |> Jason.decode!()

    assert {:ok, _} = JsonLiveviewRender.Spec.validate(spec, catalog_module)

    html =
      JsonLiveviewRender.Test.render_spec(spec, catalog_module,
        registry: registry_module,
        current_user: %{role: :member},
        authorizer: authorizer_module,
        bindings: %{}
      )

    assert html =~ "Revenue"
    assert html =~ "$42k"
  end
end
