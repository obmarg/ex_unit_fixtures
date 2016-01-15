defmodule ExUnitFixturesImpTest do
  use ExUnit.Case

  alias ExUnitFixtures.Imp
  alias ExUnitFixtures.FixtureDef

  test "test_scoped_fixtures fails when given a missing fixture" do
    assert_raise RuntimeError, ~r/Could not find a fixture named test/, fn ->
      Imp.test_scoped_fixtures(%{fixtures: [:test]}, %{})
    end
  end

  test "test_scoped_fixtures suggests other fixtures when missing" do
    assert_raise RuntimeError, ~r/Did you mean test\?$/, fn ->
      fixture_defs = %{test: %FixtureDef{name: :test},
                        other: %FixtureDef{name: :other}}

      Imp.test_scoped_fixtures(%{fixtures: [:tets]}, fixture_defs)
    end
  end
end
