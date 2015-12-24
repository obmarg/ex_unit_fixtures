defmodule ExunitFixturesTest do
  use ExUnitFixtures

  use ExUnit.Case
  doctest ExUnitFixtures

  deffixture simple do
    "simple"
  end

  deffixture not_so_simple(simple) do
    {:not_so_simple, simple}
  end

  deffixture fixture_with_context(context) do
    context.fun_things
  end

  deffixture ref do
    make_ref
  end

  deffixture ref_child1(ref) do
    ref
  end

  deffixture ref_child2(ref) do
    ref
  end

  setup do
    {:ok, %{setup_ran: true}}
  end

  test "deffixture generates a function that can create a fixture" do
    assert fixture_create_simple == "simple"
  end

  test "deffixture adds the fixture to @fixtures" do
    expected = %ExUnitFixtures.FixtureInfo{name: :simple,
                                           func: {ExunitFixturesTest,
                                                  :fixture_create_simple}}
    assert expected in @fixtures
  end

  @tag fixtures: [:simple]
  test "tagging with fixtures loads in the fixtures", context do
    assert context.simple == "simple"
  end

  test "not tagging with fixtures loads in nothing", context do
    refute Map.has_key?(context, :simple)
    refute Map.has_key?(context, :complex)
  end

  @tag fixtures: [:not_so_simple]
  test "deffixture with dependencies", context do
    assert context.not_so_simple == {:not_so_simple, "simple"}
    refute Map.has_key?(context, :simple)
  end

  @tag fixtures: [:not_so_simple, :simple]
  test "deffixture with dependencies & parent dependencies", context do
    assert context.not_so_simple == {:not_so_simple, "simple"}
    assert context.simple == "simple"
  end

  @tag fixtures: [:ref_child1, :ref_child2, :ref]
  test "fixture dependencies only created once", context do
    assert context.ref_child1 == context.ref
    assert context.ref_child2 == context.ref
  end

  @tag fixtures: [:simple]
  test "other setup functions still run", context do
    assert context.setup_ran
  end

  test "fixtures_for_context fails when given a missing fixture" do
    assert_raise RuntimeError, ~r/Could not find a fixture named test/, fn ->
      ExUnitFixtures.fixtures_for_context(%{fixtures: [:test]}, %{})
    end
  end

  test "fixtures_for_context suggests other fixtures when missing" do
    assert_raise RuntimeError, ~r/Did you mean test\?$/, fn ->
      ExUnitFixtures.fixtures_for_context(%{fixtures: [:tets]},
                                          %{test: :test, other: :other})
    end
  end

  @tag fixtures: [:fixture_with_context]
  @tag fun_things: "Clowns"
  test "fixtures can access the test context", context do
    assert context.fixture_with_context == "Clowns"
  end
end
