defmodule AutoLoadFixtures do
  use ExUnitFixtures.FixtureModule
  use ExUnitFixtures.AutoImport

  deffixture not_top_level_fixture do

    on_exit fn ->
      1
    end

    :not_top
  end

  deffixture fixture_that_uses_top(top_level_fixture) do
    {top_level_fixture, :middle}
  end
end
