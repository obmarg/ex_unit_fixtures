defmodule ExUnitFixtures.AutoLoad do
  @moduledoc """
  This module implements fixture module auto-loading.

  This is required to make sure that all fixture modules are loaded into the VM
  ready to be used while tests are running. It's possible to implement this
  manually using `Code.load_file`, but this provides an easier option.
  """

  @doc """
  Auto loads all fixture files it finds matching `fixture_pattern`.
  """
  @spec load_fixtures(Regex.t) :: nil
  def load_fixtures(fixture_pattern \\ "test/**/fixtures.exs") do
    paths = Path.wildcard(fixture_pattern)
    modules = Enum.map(paths, &Code.load_file/1)
  end
end
