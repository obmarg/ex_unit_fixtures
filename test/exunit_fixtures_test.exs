defmodule ExunitFixturesTest do
  use ExUnitFixtures

  use ExUnit.Case
  doctest ExUnitFixtures

  ExUnitFixtures.deffixture simple do
    "simple"
  end

  test "deffixture generates a function that can create a fixture" do
    assert fixture_create_simple == "simple"
  end

  test "deffixture adds the fixture to @fixtures" do
    assert @fixtures == [
      %ExUnitFixtures.FixtureInfo{name: :simple,
                                  func: {ExunitFixturesTest,
                                         :fixture_create_simple}}
    ]
  end

  @tag fixtures: [:simple]
  test "tagging with fixtures loads in the fixtures", context do
    assert context.simple == "simple"
  end

  test "not tagging with fixtures loads in nothing", context do
    refute Map.has_key?(context, :simple)
  end
end
