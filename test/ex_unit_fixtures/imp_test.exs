defmodule ExUnitFixturesImpTest do
  use ExUnit.Case

  alias ExUnitFixtures.Imp
  alias ExUnitFixtures.FixtureInfo

  test "test_scoped_fixtures fails when given a missing fixture" do
    assert_raise RuntimeError, ~r/Could not find a fixture named test/, fn ->
      Imp.test_scoped_fixtures(%{fixtures: [:test]}, %{})
    end
  end

  test "test_scoped_fixtures suggests other fixtures when missing" do
    assert_raise RuntimeError, ~r/Did you mean test\?$/, fn ->
      fixture_infos = %{test: %FixtureInfo{name: :test},
                        other: %FixtureInfo{name: :other}}

      Imp.test_scoped_fixtures(%{fixtures: [:tets]}, fixture_infos)
    end
  end

  test "module level fixtures can not depend on test level fixtures" do
    assert_raise RuntimeError, ~r/scoped to the test/, fn ->
      fixture_infos = %{mod: %FixtureInfo{name: :mod, scope: :module,
                                          dep_names: [:test]},
                        test: %FixtureInfo{name: :test, scope: :test}}

      Imp.module_scoped_fixtures(fixture_infos)
    end
  end

end
