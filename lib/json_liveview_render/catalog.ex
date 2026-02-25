defmodule JsonLiveviewRender.Catalog do
  @moduledoc """
  DSL for defining the component catalog available to JsonLiveviewRender specs.

  Example:

      defmodule MyApp.UICatalog do
        use JsonLiveviewRender.Catalog

        component :metric do
          description "Single KPI"
          prop :label, :string, required: true
          prop :value, :string, required: true
        end
      end
  """

  alias JsonLiveviewRender.Catalog.ComponentDef
  alias JsonLiveviewRender.Catalog.PropDef
  alias JsonLiveviewRender.Catalog.Primitives

  @doc "Returns sorted component types from a catalog module."
  @spec types(module()) :: [atom()]
  def types(catalog_module), do: catalog_module.components() |> Map.keys() |> Enum.sort()

  @doc "Returns prop metadata for a component type from a catalog module."
  @spec props_for(module(), atom() | String.t()) ::
          {:ok, %{optional(atom()) => PropDef.t()}} | :error
  def props_for(catalog_module, type) do
    case catalog_module.component(type) do
      %ComponentDef{props: props} -> {:ok, props}
      nil -> :error
    end
  end

  @doc "Returns true if a component type exists in the catalog module."
  @spec exists?(module(), atom() | String.t()) :: boolean()
  def exists?(catalog_module, type), do: catalog_module.has_component?(type)

  defmacro __using__(opts \\ []) do
    include_primitives = Keyword.get(opts, :include_primitives, true)

    quote bind_quoted: [include_primitives: include_primitives] do
      import JsonLiveviewRender.Catalog,
        only: [
          component: 2,
          description: 1,
          prop: 2,
          prop: 3,
          slot: 1,
          slot: 2,
          permission: 1
        ]

      Module.register_attribute(__MODULE__, :genui_components, accumulate: true)
      Module.register_attribute(__MODULE__, :genui_current_component, persist: false)
      Module.put_attribute(__MODULE__, :genui_include_primitives, include_primitives)

      @before_compile JsonLiveviewRender.Catalog
    end
  end

  defmacro component(name, do: block) do
    quote do
      JsonLiveviewRender.Catalog.__start_component__(__MODULE__, unquote(name))
      unquote(block)
      JsonLiveviewRender.Catalog.__finish_component__(__MODULE__)
    end
  end

  defmacro description(text) do
    quote bind_quoted: [text: text] do
      JsonLiveviewRender.Catalog.__set_description__(__MODULE__, text)
    end
  end

  defmacro prop(name, type, opts \\ []) do
    quote bind_quoted: [name: name, type: type, opts: opts] do
      JsonLiveviewRender.Catalog.__add_prop__(__MODULE__, name, type, opts)
    end
  end

  defmacro slot(name, _opts \\ []) do
    quote bind_quoted: [name: name] do
      JsonLiveviewRender.Catalog.__add_slot__(__MODULE__, name)
    end
  end

  defmacro permission(role) do
    quote bind_quoted: [role: role] do
      JsonLiveviewRender.Catalog.__set_permission__(__MODULE__, role)
    end
  end

  @doc false
  def __start_component__(module, name) when is_atom(name) do
    Module.put_attribute(module, :genui_current_component, ComponentDef.new(name))
  end

  @doc false
  def __finish_component__(module) do
    component = __fetch_current_component!(module)
    Module.delete_attribute(module, :genui_current_component)
    Module.put_attribute(module, :genui_components, component)
  end

  @doc false
  def __set_description__(module, description) when is_binary(description) do
    component =
      module
      |> __fetch_current_component!()
      |> ComponentDef.put_description(description)

    Module.put_attribute(module, :genui_current_component, component)
  end

  @doc false
  def __add_prop__(module, name, type, opts) when is_atom(name) and is_list(opts) do
    prop = %PropDef{
      name: name,
      type: normalize_type(type),
      required: Keyword.get(opts, :required, false),
      default: Keyword.get(opts, :default, nil),
      doc: Keyword.get(opts, :doc),
      values: Keyword.get(opts, :values),
      validator: Keyword.get(opts, :validator),
      binding_type: Keyword.get(opts, :binding_type)
    }

    validate_prop!(prop)
    validate_binding_type_opt!(prop.binding_type)

    component =
      module
      |> __fetch_current_component!()
      |> ComponentDef.put_prop(prop)

    Module.put_attribute(module, :genui_current_component, component)
  end

  @doc false
  def __add_slot__(module, slot_name) when is_atom(slot_name) do
    component =
      module
      |> __fetch_current_component!()
      |> ComponentDef.put_slot(slot_name)

    Module.put_attribute(module, :genui_current_component, component)
  end

  @doc false
  def __set_permission__(module, role) when is_atom(role) do
    component =
      module
      |> __fetch_current_component!()
      |> ComponentDef.put_permission(role)

    Module.put_attribute(module, :genui_current_component, component)
  end

  @doc false
  defmacro __before_compile__(env) do
    include_primitives = Module.get_attribute(env.module, :genui_include_primitives)

    declared_components =
      env.module
      |> Module.get_attribute(:genui_components)
      |> Enum.reverse()
      |> Enum.into(%{}, fn %ComponentDef{name: name} = comp -> {name, comp} end)

    components =
      if include_primitives do
        Map.merge(Primitives.components(), declared_components)
      else
        declared_components
      end

    quote bind_quoted: [components: Macro.escape(components)] do
      @genui_compiled_components components

      @doc false
      def __genui_catalog__, do: @genui_compiled_components

      @doc "Returns all components in the catalog as a map keyed by type atom."
      def components, do: __genui_catalog__()

      @doc "Returns sorted component types in this catalog."
      def types, do: __genui_catalog__() |> Map.keys() |> Enum.sort()

      @doc "Returns a component definition by atom or string type."
      def component(type)

      def component(type) when is_atom(type), do: Map.get(__genui_catalog__(), type)

      def component(type) when is_binary(type) do
        Enum.find_value(__genui_catalog__(), fn {name, component} ->
          if Atom.to_string(name) == type, do: component
        end)
      end

      @doc "Checks if a component type exists in the catalog."
      def has_component?(type), do: not is_nil(component(type))

      @doc "Returns prop definitions for a given component type."
      def props_for(type) do
        case component(type) do
          %ComponentDef{props: props} -> {:ok, props}
          nil -> :error
        end
      end

      @doc "Alias for has_component?/1."
      def exists?(type), do: has_component?(type)
    end
  end

  defp __fetch_current_component!(module) do
    case Module.get_attribute(module, :genui_current_component) do
      %ComponentDef{} = component ->
        component

      _ ->
        raise ArgumentError,
              "catalog DSL call must be nested inside component/2 in #{inspect(module)}"
    end
  end

  defp normalize_type({:list, type}), do: {:list, normalize_type(type)}
  defp normalize_type(type), do: type

  defp validate_prop!(%PropDef{type: :enum, values: values})
       when is_list(values) and values != [], do: :ok

  defp validate_prop!(%PropDef{type: :enum}) do
    raise ArgumentError, "enum prop type requires non-empty :values option"
  end

  defp validate_prop!(%PropDef{type: :custom, validator: validator})
       when is_function(validator, 1), do: :ok

  defp validate_prop!(%PropDef{type: :custom}) do
    raise ArgumentError, "custom prop type requires :validator option with arity 1 function"
  end

  defp validate_prop!(%PropDef{type: {:list, type}}) do
    validate_prop!(%PropDef{name: :_inner, type: type})
  end

  defp validate_prop!(%PropDef{type: type})
       when type in [:string, :integer, :float, :boolean, :map],
       do: :ok

  defp validate_prop!(%PropDef{type: invalid}) do
    raise ArgumentError, "unsupported prop type: #{inspect(invalid)}"
  end

  defp validate_binding_type!({:list, inner}), do: validate_binding_type!(inner)

  defp validate_binding_type!(type) when type in [:string, :integer, :float, :boolean, :map],
    do: :ok

  defp validate_binding_type!(invalid) do
    raise ArgumentError,
          "unsupported :binding_type #{inspect(invalid)}; use primitive or list primitive types"
  end

  defp validate_binding_type_opt!(nil), do: :ok
  defp validate_binding_type_opt!(binding_type), do: validate_binding_type!(binding_type)
end
