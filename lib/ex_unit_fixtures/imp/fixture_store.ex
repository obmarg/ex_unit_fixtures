defmodule ExUnitFixtures.Imp.FixtureStore do
  @moduledoc false

  @doc """
  Stores fixtures for a session/module.
  """
  def start_link do
    Agent.start_link(&Map.new/0)
  end

  @doc """
  Gets or creates a fixture by it's `qualified_name`.

  `create_fun` should be a single arg fun that takes the current fixtures dict.
  """
  def get_or_create(store, qualified_name, create_fun) do
    Agent.get_and_update(store, fn fixtures ->
      if Map.has_key?(fixtures, qualified_name) do
        {fixtures[qualified_name], fixtures}
      else
        fixture = create_fun.(fixtures)
        {fixture, Map.put(fixtures, qualified_name, fixture)}
      end
    end)
  end
end
