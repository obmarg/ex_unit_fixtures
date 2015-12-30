defmodule ExUnitFixtures do
  @moduledoc """
  A library for declaring & using test fixtures in ExUnit.

  To use ExUnitFixtures, you should `use ExUnitFixtures` in your test case
  (before `use ExUnit.Case`), and then define your fixtures using
  `deffixture/3`. These fixtures can then be used by tagging your tests with the
  `fixtures` tag. For example:

      iex(2)> defmodule MyTests do
      ...(2)>   use ExUnitFixtures
      ...(2)>   use ExUnit.Case
      ...(2)>
      ...(2)>   deffixture my_model do
      ...(2)>     # Create a model somehow...
      ...(2)>     %{test: 1}
      ...(2)>   end
      ...(2)>
      ...(2)>   @tag fixtures: [:my_model]
      ...(2)>   test "that we have some fixtures", context do
      ...(2)>     assert context.my_model.test == 1
      ...(2)>   end
      ...(2)> end
      iex(3)> Module.defines?(MyTests, :create_my_model)
      true

  #### Fixtures with dependencies

  Fixtures can also depend on other fixtures by naming a parameter after that
  fixture. For example, if you needed to setup a database instance before
  creating some models:

      iex(4)> defmodule MyTests2 do
      ...(4)>   use ExUnitFixtures
      ...(4)>   use ExUnit.Case
      ...(4)>
      ...(4)>   deffixture database do
      ...(4)>     # set up the database somehow...
      ...(4)>   end
      ...(4)>
      ...(4)>   deffixture my_model(database) do
      ...(4)>     # use the database to insert a model
      ...(4)>   end
      ...(4)>
      ...(4)>   @tag fixtures: [:my_model]
      ...(4)>   test "something", %{my_model: my_model} do
      ...(4)>     # Test something with my_model
      ...(4)>   end
      ...(4)> end
      iex(5)> Module.defines?(MyTests2, :create_database)
      true
      iex(6)> Module.defines?(MyTests2, :create_my_model)
      true

  In the sample above, we have 2 fixtures: one which creates the database and
  another which inserts a model into that database. The test function depends on
  `my_model` which depends on the database. ExUnitFixtures knows this, and takes
  care of setting up the database and passing it in to `my_model`.

  #### Tearing down Fixtures

  If you need to do some teardown work for a fixture you can use the ExUnit
  `on_exit` function:

      iex(8)>     defmodule TestWithTearDowns do
      ...(8)>       use ExUnitFixtures
      ...(8)>       use ExUnit.Case
      ...(8)>
      ...(8)>       deffixture database do
      ...(8)>         # Setup the database
      ...(8)>         on_exit fn ->
      ...(8)>           # Tear down the database
      ...(8)>           nil
      ...(8)>         end
      ...(8)>       end
      ...(8)>     end
      iex(9)> Module.defines?(MyTests2, :create_database)
      true
  """

  alias ExUnitFixtures.FixtureInfo

  @doc """
  Defines a fixture local to a test module.

  This is intended to be used much like a def statement:

      deffixture my_fixture do
        "my_fixture_text"
      end

  A fixture may optionally depend on other fixtures. This is done by creating a
  fixture that accepts parameters named after other fixtures. These fixtures
  will automatically be run and injected as parameters to the current fixture.
  For example:

      deffixture database do
        %{database: true}
      end

      deffixture model(database) do
        %{model: true}
      end
  """
  defmacro deffixture({name, info, params}, opts \\ [], body) do
    if name == :context do
      raise """
      The name context is reserved for the ExUnit context.
      It may not be used for fixtures.
      """
    end

    create_name = :"fixture_create_#{name}"
    dep_names = for {dep_name, _, _} <- params || [] do
      dep_name
    end

    scope = Dict.get(opts, :scope, :function)

    quote do
      def unquote({create_name, info, params}), unquote(body)

      @fixtures %FixtureInfo{name: unquote(name),
                             func: {__MODULE__, unquote(create_name)},
                             dep_names: unquote(dep_names),
                             scope: unquote(scope)}
    end
  end

  defmacro __using__(_opts) do
    quote do
      if is_list(Module.get_attribute(__MODULE__, :ex_unit_tests)) do
        raise "`use ExUnitFixtures` must come before `use ExUnit.Case`"
      end

      Module.register_attribute __MODULE__, :fixtures, accumulate: true
      @before_compile ExUnitFixtures

      import ExUnitFixtures
    end
  end

  defmacro __before_compile__(_) do
    quote do
      @_grouped_fixtures for f <- @fixtures, into: %{}, do: {f.name, f}

      setup_all do
        {:ok, ExUnitFixtures.Imp.module_scoped_fixtures(@_grouped_fixtures)}
      end

      setup context do
        {:ok, ExUnitFixtures.Imp.test_scoped_fixtures(context,
                                                      @_grouped_fixtures)}
      end
    end
  end
end
