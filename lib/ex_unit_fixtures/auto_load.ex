defmodule ExUnitFixtures.AutoLoad do
  @moduledoc """
  This module provides an interface that will load fixture files in tests.

  By default ExUnit does not load files in the test folder globally - each
  individual tests will have access to modules defined in it's file, but not to
  modules defined in any other file in the test directory.

  This can be worked around manually by calling `Code.load_file` or similar in
  your `test_helper.exs` for each fixture file, but that's a bit of a pain.

  AutoLoad takes care of loading all files named `fixtures.exs` in the current
  test files directory, and any parent directories. It also calls `use` on those
  files, so that all the fixtures are avaliable for use in the current test.
  This means that users just need to call `use ExUnitFixtures.AutoLoad` at the
  start of their tests, and any appropriate fixtures will automatically be
  available.

  Users are still free to import additional fixtures from any other location,
  but this provides a simple option for providing a hierarchy of fixtures that
  should do for many uses.
  """

  defmacro __using__(_) do
    quote do
      __DIR__
      |> ExUnitFixtures.AutoLoad.relevant_fixture_files(~r/^fixtures.exs$/i)
      |> Enum.map(&Code.load_file/1)
    end
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
    directory
    |> File.ls!
    |> Enum.filter(&Regex.match? fixture_regex, &1)
    |> Enum.map(&Path.join directory, &1)
  end
end
