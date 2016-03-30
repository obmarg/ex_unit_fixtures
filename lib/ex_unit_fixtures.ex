defmodule ExUnitFixtures do
  @moduledoc """
  A library for declaring & using test fixtures in ExUnit.

  For an overview of it's purpose see the [README](README.html).

  To use ExUnitFixtures we need to start it. Add the following code to your
  `test_helpers.exs`:

      ExUnitFixtures.start

  This starts the ExUnitFixtures application and imports any `fixtures.exs`
  files that are found in the test directory heiararchy. See
  `ExUnitFixtures.start/1` for more details.

  Next you should:

  1. Add `use ExUnitFixtures` to your test cases (before `use ExUnit.Case`)
  2. Define some fixtures using `deffixture/3`
  3. Tag some tests with `@tag fixtures: [:your_fixtures_here]`

  The tagged tests will automatically have all the requested fixtures injected
  into their `context`. For example:

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

  ## Fixtures with dependencies

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

  ## Fixture Scoping

  Fixtures may optionally be provided with a scope:

  - `:test` scoped fixtures will be created before each test that requires them
    and not re-used between tests. Their teardown will run after the test has
    finished. This is the default scope for a fixture.
  - `:module` scoped fixtures will be created once at the start of a test module
    and re-used in any test that requires them. Their teardown will run after
    the entire modules tests have run.

  For details on how to specify scopes, see `deffixture/3`.

  ## Tearing down Fixtures

  If you need to do some teardown work for a fixture you can use the
  `teardown/2` function.

      iex(8)> defmodule TestWithTearDowns do
      ...(8)>   use ExUnitFixtures
      ...(8)>   use ExUnit.Case
      ...(8)>
      ...(8)>   deffixture database, scope: :module do
      ...(8)>     # Setup the database
      ...(8)>     teardown :module, fn ->
      ...(8)>       # Tear down the database
      ...(8)>       nil
      ...(8)>     end
      ...(8)>   end
      ...(8)>
      ...(8)>   deffixture model do
      ...(8)>     # Insert the model
      ...(8)>     teardown :test, fn ->
      ...(8)>       # Delete the model
      ...(8)>       nil
      ...(8)>     end
      ...(8)>   end
      ...(8)> end
      iex(9)> Module.defines?(MyTests2, :create_database)
      true

  ## Sharing Fixtures Amongst Test Cases.

  It is possible to share fixtures among test cases by declaring that module a
  fixture module. See `ExUnitFixtures.FixtureModule` for more details.

  When started, `ExUnitFixtures` automatically loads any `fixtures.exs` files it
  finds in the test directory hierarchy. Any test or fixture module will also
  automatically import any fixtures defined in `fixtures.exs` files in it's
  current or parent directories. This allows ExUnitFixtures to provide a
  powerful yet simple method of sharing fixtures amongst tests in a directory
  heirarchy.  See `ExUnitFixtures.AutoImport` for more details.
  """

  alias ExUnitFixtures.FixtureDef

  @doc """
  Starts the ExUnitFixtures application.

  By default this will also look for any `fixtures.exs` files in the test
  directory and load them into the VM so we can use the fixtures contained
  within. This can be controlled by the `auto_load` option described below.

  The keyword list `opts` may be provided to override any of the default
  options.

  ### Options

  - `auto_import` controls whether tests & fixture modules should automatically
    import fixtures from `fixtures.exs` files in their directory tree. This is
    true by default
  - `auto_load` controls whether `ExUnitFixtures` should automatically load
    `fixtures.exs` files it finds in the test directory tree on startup. This is
    true by default.
  """
  def start(opts \\ []) do
    Enum.each opts, fn {key ,val} ->
      Application.put_env(:ex_unit_fixtures, key, val, persistent: true)
    end
    Application.ensure_all_started(:ex_unit_fixtures)
  end

  @doc false
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(ExUnitFixtures.Teardown, []),
      worker(ExUnitFixtures.Imp.ModuleStore, [])
    ] ++
    if Application.get_env(:ex_unit_fixtures, :auto_load) do
      [worker(ExUnitFixtures.Imp.FileLoader, [])]
    else
      []
    end

    Supervisor.start_link(children, strategy: :one_for_one, name: ExUnitFixtures)
  end

  @doc """
  Loads all files it finds matching `fixture_pattern` into the VM.
  """
  @spec load_fixture_files(Regex.t) :: nil
  def load_fixture_files(fixture_pattern \\ "test/**/fixtures.exs") do
    ExUnitFixtures.Imp.FileLoader.load_fixture_files(fixture_pattern)
  end

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

  #### Fixture Options

  Fixtures can accept various options that control how they are defined:

      deffixture database, scope: :module do
        %{database: true}
      end

  These options are supported:

  - `scope` controls the scope of fixtures. See Fixture Scoping for details.
  - Passing `autouse: true` will cause a fixture to be passed to every test in
    the module.
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

    scope = Dict.get(opts, :scope, :test)
    autouse = Dict.get(opts, :autouse, false)

    quote do
      ExUnitFixtures.Imp.Preprocessing.check_clashes(unquote(name), @fixtures)

      def unquote({create_name, info, params}), unquote(body)

      @fixtures %FixtureDef{
        name: unquote(name),
        func: {__MODULE__, unquote(create_name)},
        dep_names: unquote(dep_names),
        scope: unquote(scope),
        autouse: unquote(autouse),
        qualified_name: Module.concat(__MODULE__, unquote(name))
      }
    end
  end

  @doc """
  Registers a teardown function for the current test pid.

  `scope` should be provided, and should usually match the scope of the current
  fixture. It determines whether the teardown should be run at the end of the
  test or end of the module.

  There are some use-cases for providing a non-matching scope. You might want
  to reset a module fixture inbetween each of the individual tests, which could
  easily be done with a test scoped teardown.
  """
  @spec teardown(:test | :module, fun) :: :ok
  def teardown(scope \\ :test, fun) do
    ExUnitFixtures.Teardown.register_teardown(scope, fun)
  end

  defmacro __using__(_opts) do
    quote do
      if is_list(Module.get_attribute(__MODULE__, :ex_unit_tests)) do
        raise "`use ExUnitFixtures` must come before `use ExUnit.Case`"
      end

      Module.register_attribute(__MODULE__,
                                :fixture_modules,
                                accumulate: true)

      Module.register_attribute __MODULE__, :fixtures, accumulate: true
      @before_compile ExUnitFixtures

      import ExUnitFixtures

      if Application.get_env(:ex_unit_fixtures, :auto_import) do
        use ExUnitFixtures.AutoImport
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      @_processed_fixtures ExUnitFixtures.Imp.Preprocessing.preprocess_fixtures(
        @fixtures, @fixture_modules
      )

      setup_all do
        {:ok, module_store} = ExUnitFixtures.Imp.FixtureStore.start_link
        module_ref = make_ref

        ExUnitFixtures.Teardown.register_pid(module_ref, module_store)

        on_exit fn ->
          ExUnitFixtures.Teardown.run(module_ref)
        end

        {:ok, %{__ex_unit_fixtures: %{module_store: module_store,
                                      module_ref: module_ref}}}
      end

      setup context do
        %{__ex_unit_fixtures: fixture_context} = context

        ExUnitFixtures.Teardown.register_pid(fixture_context[:module_ref])

        {:ok, ExUnitFixtures.Imp.create_fixtures(
            context[:fixtures] || [],
            @_processed_fixtures,
            %{module: fixture_context[:module_store]},
            context
        )}
      end
    end
  end
end
