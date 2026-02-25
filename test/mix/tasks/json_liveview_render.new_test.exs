defmodule Mix.Tasks.JsonLiveviewRender.NewTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @task "json_liveview_render.new"

  setup do
    Mix.Task.reenable(@task)

    tmp_dir =
      Path.join(
        System.tmp_dir!(),
        "json_liveview_render_new_test_#{System.unique_integer([:positive, :monotonic])}"
      )

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    {:ok, tmp_dir: tmp_dir}
  end

  test "generates starter files for an explicit module", %{tmp_dir: tmp_dir} do
    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.New.run([tmp_dir, "--module", "Acme.App"])
      end)

    assert output =~ "JsonLiveviewRender starter files generated for Acme.App."
    assert File.exists?(Path.join(tmp_dir, "lib/acme/app/json_liveview_render/catalog.ex"))
    assert File.exists?(Path.join(tmp_dir, "lib/acme/app/json_liveview_render/components.ex"))
    assert File.exists?(Path.join(tmp_dir, "lib/acme/app/json_liveview_render/registry.ex"))
    assert File.exists?(Path.join(tmp_dir, "lib/acme/app/json_liveview_render/authorizer.ex"))
    assert File.exists?(Path.join(tmp_dir, "priv/json_liveview_render/example_spec.json"))

    catalog = File.read!(Path.join(tmp_dir, "lib/acme/app/json_liveview_render/catalog.ex"))
    assert catalog =~ "defmodule Acme.App.JsonLiveviewRender.Catalog"
  end

  test "infers module name from target folder when --module is not provided", %{tmp_dir: tmp_dir} do
    target = Path.join(tmp_dir, "billing_portal")
    File.mkdir_p!(target)

    capture_io(fn ->
      Mix.Tasks.JsonLiveviewRender.New.run([target])
    end)

    catalog = File.read!(Path.join(target, "lib/billing_portal/json_liveview_render/catalog.ex"))
    assert catalog =~ "defmodule BillingPortal.JsonLiveviewRender.Catalog"
  end

  test "refuses to overwrite existing files without --force", %{tmp_dir: tmp_dir} do
    capture_io(fn ->
      Mix.Tasks.JsonLiveviewRender.New.run([tmp_dir, "--module", "Acme.App"])
    end)

    Mix.Task.reenable(@task)

    assert_raise Mix.Error, ~r/refusing to overwrite/, fn ->
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.New.run([tmp_dir, "--module", "Acme.App"])
      end)
    end
  end

  test "overwrites existing files when --force is provided", %{tmp_dir: tmp_dir} do
    capture_io(fn ->
      Mix.Tasks.JsonLiveviewRender.New.run([tmp_dir, "--module", "Acme.App"])
    end)

    registry_path = Path.join(tmp_dir, "lib/acme/app/json_liveview_render/registry.ex")
    File.write!(registry_path, "defmodule Placeholder do end\n")

    Mix.Task.reenable(@task)

    output =
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.New.run([tmp_dir, "--module", "Acme.App", "--force"])
      end)

    assert output =~ "* overwriting lib/acme/app/json_liveview_render/registry.ex"
    assert File.read!(registry_path) =~ "defmodule Acme.App.JsonLiveviewRender.Registry"
  end

  test "raises on invalid module names", %{tmp_dir: tmp_dir} do
    assert_raise Mix.Error, ~r/invalid --module/, fn ->
      capture_io(fn ->
        Mix.Tasks.JsonLiveviewRender.New.run([tmp_dir, "--module", "acme.app"])
      end)
    end
  end
end
