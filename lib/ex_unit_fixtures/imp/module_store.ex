defmodule ExUnitFixtures.Imp.ModuleStore do
  @moduledoc false
  # This module provides a store for fixture module metadata.
  # When a FixtureModule is first defined it should register itself with the
  # module store. This allows other modules to automatically import fixture
  # modules using the metadata in the module store.

  @doc false
  def start_link() do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @doc """
  Registers `module` in `file` in the store.
  """
  @spec register(atom, String.t) :: :ok
  def register(module, file) do
    check_server_running

    Agent.update __MODULE__, fn modules ->
      [{module, file} | modules]
    end
  end

  @doc """
  Finds all fixture modules contained within a file.
  """
  @spec find_file(String.t) :: [:atom]
  def find_file(filename) do
    check_server_running

    filename = Path.absname(filename)
    Agent.get __MODULE__, fn state ->
      for {module, mod_file} <- state, mod_file == filename, do: module
    end
  end

  @doc """
  Finds the file a module is contained within.
  """
  @spec find_module(:atom) :: String.t
  def find_module(search_module) do
    check_server_running

    __MODULE__
    |> Agent.get(fn state ->
      for {module, mod_file} <- state, search_module == module, do: mod_file
    end)
    |> List.first
  end

  @spec check_server_running :: nil | no_return
  defp check_server_running do
    if Process.whereis(__MODULE__) == nil do
      raise """
      You must call `ExUnitFixtures.start` before registering a FixtureModule.
      It's recommended to do this in your `test_helpers.exs` file.
      """
    end
  end
end
