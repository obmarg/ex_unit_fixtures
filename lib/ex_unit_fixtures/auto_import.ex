defmodule ExUnitFixtures.AutoImport do
  @moduledoc """
  A mechanism for automatically importing fixtures into the current test module.

  In a relatively large test suite you'll most likely need to declare some
  fixtures that are to be shared between all tests in a project or module.
  `ExUnitFixtures.AutoImport` provides a method for automatically importing
  fixtures into a test module based on the module's path.

  When a module uses `ExUnitFixtures.AutoImport` it will automatically lookup
  `fixtures.exs` files in the current and parent directories and import the
  fixtures they contain into the current test file for use.

  Note: By default, any call to `use ExUnitFixtures` or
  `use ExUnitFixtures.FixtureModule` will automatically
  `use ExUnitFixtures.AutoImport` so this module should not need to be manually
  used most of the time. This can be controlled by the `auto_import` setting as
  described in `ExUnitFixtures.start/1`

  For example, we could use the following directory structure & tests:

      tests/
          fixtures.exs
              defmodule GlobalFixtures do
                use ExUnitFixtures.FixtureModule

                deffixture db do
                  create_db_conn()
                end
              end

          model_tests/
              fixtures.exs
                  defmodule ModelFixtures do
                    use ExUnitFixtures.FixtureModule

                    deffixture user(db) do
                      user = %User{name: "Graeme"}
                      insert(db, user)
                      user
                    end
                  end

              user_tests.exs
                  defmodule UserTests do
                    use ExUnitFixtures

                    @fixtures: :user
                    test "user has name", context do
                      assert context.user.name == "Graeme"
                    end

  Here we declare a fixtures.exs file at our top-level that contains a database
  fixture that any of our tests can access. We then define some fixtures for all
  of our model tests, and use the user fixture inside one of those tests.
  """

  defmacro __using__(_opts) do
    quote do
      modules = __DIR__
      |> ExUnitFixtures.AutoImport.relevant_fixture_files(~r/^fixtures.exs$/i)
      |> Enum.flat_map(&ExUnitFixtures.Imp.ModuleStore.find_file/1)

      for module <- modules, module != __MODULE__ do
        ExUnitFixtures.AutoImport.require_fixture_module(module)
      end
    end
  end

  @doc """
  Imports a the fixture module `module` into the calling module.
  """
  defmacro require_fixture_module(module) do
    ExUnitFixtures.FixtureModule.register_fixtures(module)
  end

  @doc """
  Finds any fixture files in the current directory or parent directories.

  Uses fixture_regex to match fixture files. Returns the results in descending
  directory hierarchy order, but files of the same level are not in a guaranteed
  order.
  """
  @spec relevant_fixture_files(String.t, Regex.t) :: [String.t]
  def relevant_fixture_files(directory, fixture_regex) do
    directory
    |> find_mix_root
    |> directories_between(directory)
    |> Enum.flat_map(&matching_files &1, fixture_regex)
    |> Enum.into([])
  end

  # Finds a parent directory with a mix.exs in it.
  @spec find_mix_root(String.t) :: String.t | no_return
  defp find_mix_root("/") do
    raise "Could not find directory with mix.exs"
  end
  defp find_mix_root(directory) do
    if File.exists?(Path.join(directory, "mix.exs")) do
      directory
    else
      directory |> Path.join("..") |> Path.expand |> find_mix_root
    end
  end

  # Returns a list of directories between parent & child.
  @spec directories_between(String.t, String.t) :: [String.t]
  defp directories_between(parent, child) do
    child
    |> Path.relative_to(parent)
    |> Path.split
    |> Enum.scan(parent, &(Path.join &2, &1))
  end

  # Returns a list of files in directory that match fixture_regex.
  # Returns the full path to the files, but the regex only needs to match the
  # file name.
  @spec matching_files(String.t, Regex.t) :: [String.t]
  defp matching_files(directory, fixture_regex) do
    if File.dir?(directory) do
      directory
      |> File.ls!
      |> Enum.filter(&Regex.match? fixture_regex, &1)
      |> Enum.map(&Path.join directory, &1)
    else
      []
    end
  end
end
