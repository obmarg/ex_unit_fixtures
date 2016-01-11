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

       test "that user is inactive", %{user: user} do
         assert user.active == false
       end
     end

  #### Loading Fixture Code

  Note: The example above will work if both modules are defined in the same
  file. If not, however, you'll need to do some work to ensure your CaseTemplate is
  loaded when your tests are running. You can do this using the `Code.load_file`
  function in your `test_helper.exs` file, [as described in this stack overflow
  answer](http://stackoverflow.com/a/30652675/589746).
  """

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute __MODULE__, :fixtures, accumulate: true
      import ExUnitFixtures

      @before_compile ExUnitFixtures.FixtureModule

      Module.register_attribute(__MODULE__,
                                :fixture_modules,
                                accumulate: true)

      defmacro __using__(opts) do
        ExUnitFixtures.FixtureModule.register_fixtures(__MODULE__, opts)
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      @fixtures_ ExUnitFixtures.Imp.Preprocessing.preprocess_fixtures(
        @fixtures, @fixture_modules
      )

      def fixtures do
        @fixtures_
      end
    end
  end

  @doc """
  Body of the nested __using__ func in any module that has used `FixtureModule`.
  """
  def register_fixtures(fixture_module, _opts) do
    quote do
      Module.register_attribute(__MODULE__,
                                :fixture_modules,
                                accumulate: true)

      @fixture_modules unquote(fixture_module)
    end
  end
end
