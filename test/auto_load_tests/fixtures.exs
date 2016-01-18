defmodule AutoLoadFixtures do
  use ExUnitFixtures.FixtureModule
  use ExUnitFixtures.AutoImport

  deffixture not_top_level_fixture do
    :not_top
  end

  deffixture fixture_that_uses_top(top_level_fixture) do
    {top_level_fixture, :middle}
  end
end
