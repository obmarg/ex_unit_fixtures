defmodule ExUnitFixturesImpTest do
  use ExUnit.Case

  alias ExUnitFixtures.Imp
  
  test "fixtures_for_context fails when given a missing fixture" do
    assert_raise RuntimeError, ~r/Could not find a fixture named test/, fn ->
      Imp.fixtures_for_context(%{fixtures: [:test]}, %{})
    end
  end

  test "fixtures_for_context suggests other fixtures when missing" do
    assert_raise RuntimeError, ~r/Did you mean test\?$/, fn ->
      Imp.fixtures_for_context(%{fixtures: [:tets]},
                               %{test: :test, other: :other})
    end
  end

end
