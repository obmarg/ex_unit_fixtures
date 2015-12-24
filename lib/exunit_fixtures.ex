defmodule ExUnitFixtures do
  @moduledoc """
  A library for declaring & using fixtures in ExUnit.
  """

  defmodule FixtureInfo do
    @moduledoc """
    Stores information about a fixture.
    """

    defstruct name: nil, func: nil

    @type t :: %__MODULE__{
      name: :atom,
      func: {:atom, :atom}
    }
  end

  @doc """
  Defines a fixture.
  """
  defmacro deffixture({name, info, params}, body) do
    create_name = :"fixture_create_#{name}"
    quote do
      def unquote({create_name, info, params}), unquote(body)

      @fixtures %FixtureInfo{name: unquote(name),
                             func: {__MODULE__, unquote(create_name)}}
    end
  end

  defmacro __using__(_opts) do
    quote do
      if is_list(Module.get_attribute(__MODULE__, :ex_unit_tests)) do
        raise "must be `use ExUnitFixtures` must come before `use ExUnit.Case`"
      end
      Module.register_attribute __MODULE__, :fixtures, accumulate: true
      @before_compile ExUnitFixtures
    end
  end

  defmacro __before_compile__(_) do
    quote do
      setup context do
        {:ok, ExUnitFixtures.fixtures_for_context(context, @fixtures)}
      end
    end
  end

  @doc """
  Creates the required fixtures for a given test context.
  """
  @spec fixtures_for_context(%{}, %{}) :: %{}
  def fixtures_for_context(context, fixtures) do
    list_fixtures = context[:fixtures] || []
    Enum.reduce(list_fixtures, context, fn (fixture_name, context) ->
      Map.put(context, fixture_name, create_fixture(fixture_name, fixtures))
    end)
  end

  @spec create_fixture(:atom, %{}) :: term
  defp create_fixture(fixture_name, fixtures) do
    fixture_info = Enum.find(fixtures, fn (f) -> f.name == fixture_name end)
    {mod, func} = fixture_info.func
    :erlang.apply(mod, func, [])
  end
end
