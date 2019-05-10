defmodule ExUnitFixtures.FixtureModule do
  @moduledoc """
  Sets up a module as an importable module of fixtures.

  This module can be used in any module that defines common fixtures to be
  shared amongst many tests.

  By using `ExUnitFixtures.FixtureModule` a module will become a fixture module.
  A fixture module can be used by other test cases, as well as imported into
  other fixture modules.

  For example:

      defmodule MyFixtures do
        use ExUnitFixtures.FixtureModule

        deffixture database do
          %{db: :db}
        end

        deffixture user(database) do
          %{user: user}
        end
      end

      defmodule MyTests do
        use ExUnitFixtures
        use MyFixtures
        use ExUnit.Case

        @tag fixtures: [:user]
        test "that we have a user", %{user: user} do
          assert user == :user
        end
      end

  #### Overriding Fixtures

  When importing fixtures into a module it's possible to override some of those
  fixtures, by calling deffixture with an already used name. The overriding
  fixture may depend on the existing fixture, but any other fixture in the
  current module or importing modules will only be able to get the overriding
  fixture.

      defmodule MyFixtures do
        use ExUnitFixtures.FixtureModule

        deffixture user do
          make_user()
        end
      end

      defmodule InactiveUserTests do
        deffixture user(user) do
          %{user | active: false}
        end

        @tag fixtures: [:user]
        test "that user is inactive", %{user: user} do
          assert user.active == false
        end
      end

  #### Loading Fixture Code

  All the examples in this file have shown a fixture module defined within the
  same file as the tests. This is not too likely to happen in an actual project.
  It's more likely that you'd want to define a fixture module in one file and
  then import it into many other files.

  By default ExUnitFixtures makes this fairly easy - any file named
  `fixtures.exs` in any folder underneath `test/` will automatically be loaded
  into the VM when calling `ExUnitFixtures.start/1`.

  Any fixture modules defined within these files will also automatically be
  imported into the current module as documented in `ExUnitFixtures.AutoImport`.

  If you wish to load in fixtures that are not contained within a `fixtures.exs`
  file, then you should load them into the VM with `Code.require_file` in your
  `test_helpers.exs` and then manually `use` the fixture module.
  """

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute __MODULE__, :__fixtures, accumulate: true
      import ExUnitFixtures

      @before_compile ExUnitFixtures.FixtureModule

      Module.register_attribute(__MODULE__,
                                :fixture_modules,
                                accumulate: true)

      ExUnitFixtures.Imp.ModuleStore.register(__MODULE__, __ENV__.file)

      if Application.get_env(:ex_unit_fixtures, :auto_import) do
        use ExUnitFixtures.AutoImport
      end

      defmacro __using__(opts) do
        ExUnitFixtures.FixtureModule.register_fixtures(__MODULE__, opts)
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      @fixtures_ ExUnitFixtures.Imp.Preprocessing.preprocess_fixtures(
        @__fixtures, Enum.uniq(@fixture_modules)
      )

      def fixtures do
        @fixtures_
      end
    end
  end

  @doc """
  Body of the nested `__using__` func in any module that has used
  `FixtureModule`.
  """
  def register_fixtures(fixture_module, _opts \\ []) do
    quote do
      Module.register_attribute(__MODULE__,
                                :fixture_modules,
                                accumulate: true)

      @fixture_modules unquote(fixture_module)
    end
  end
end
