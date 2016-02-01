defmodule ExUnitFixtures.Imp.FileLoader do
  @moduledoc false
  # A GenServer that handles loading fixture files automatically.

  # It's possible for a user to call `load_fixture_files` manually themselves, but
  # writing this as a GenServer allows us to carry it out as part of the startup
  # of the ExUnitFixtures supervision tree.

  use GenServer

  @doc """
  Starts the ModuleLoader as part of a supervision tree.
  """
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  def init([]) do
    load_fixture_files()
    {:ok, [], :hibernate}
  end

  @doc """
  Loads all files it finds matching `fixture_pattern` into the VM.
  """
  @spec load_fixture_files(Regex.t) :: nil
  def load_fixture_files(fixture_pattern \\ "test/**/fixtures.exs") do
    paths =
      fixture_pattern
      |> Path.wildcard
      |> Enum.sort_by(fn (v) -> v |> Path.split |> Enum.count end)

    modules = Enum.map(paths, &Code.load_file/1)
  end
end
