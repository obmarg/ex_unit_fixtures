defmodule AutoLoadFixtures do
  use ExUnitFixtures.FixtureModule

  deffixture not_top_level_fixture do

    # Make sure that we _can_ call `on_exit` from a FixtureModule.
    on_exit fn ->
      1
    end

    :not_top
  end

  deffixture fixture_that_uses_top(top_level_fixture) do
    {top_level_fixture, :middle}
  end
end
