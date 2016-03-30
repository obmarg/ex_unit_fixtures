defmodule ExUnitFixturesImpTest do
  use ExUnit.Case

  alias ExUnitFixtures.Imp
  alias ExUnitFixtures.FixtureDef
  alias ExUnitFixtures.Imp.FixtureStore

  test "create_fixtures fails when given a missing fixture" do
    assert_raise RuntimeError, ~r/Could not find a fixture named nope/, fn ->
      Imp.create_fixtures([:nope], %{}, %{}, %{})
    end
  end

  test "create_fixtures suggests other fixtures when missing" do
    assert_raise RuntimeError, ~r/Did you mean test\?$/, fn ->
      fixture_defs = %{test: %FixtureDef{name: :test},
                        other: %FixtureDef{name: :other}}

      Imp.create_fixtures([:tets], fixture_defs, %{}, %{})
    end
  end

  @test_fixtures [
    %FixtureDef{name: :fixture_a,
                scope: :module,
                qualified_name: :"SomeModule.fixture_a",
                qualified_dep_names: [],
                func: {Kernel, :make_ref}},
    %FixtureDef{name: :fixture_b,
                scope: :test,
                dep_names: [:fixture_a],
                qualified_name: :"SomeModule.fixture_b",
                qualified_dep_names: [:"SomeModule.fixture_a"],
                func: {__MODULE__, :fixture_b_func}},
    %FixtureDef{name: :not_used,
                scope: :module,
                qualified_name: :"SomeModule.not_used",
                qualified_dep_names: [],
                func: {__MODULE__, :missing_func}}
  ]

  def fixture_b_func(fixture_a) do
    assert fixture_a != nil
    make_ref
  end

  test "resolve_fixtures correctly resolves fixtures" do
    [fixture_a, fixture_b, _] = @test_fixtures

    fixtures = map_fixtures(@test_fixtures)

    resolved = Imp.resolve_fixtures([:fixture_a, :fixture_b], fixtures)
    assert resolved == [fixture_a, fixture_b]
  end

  test "create_fixtures creates module and test fixtures" do
    {:ok, store_pid} = FixtureStore.start_link

    fixtures = map_fixtures(@test_fixtures)

    results = Imp.create_fixtures([:fixture_a, :fixture_b],
                                  fixtures, %{module: store_pid}, %{})

    assert Map.has_key?(results, :fixture_a)
    assert Map.has_key?(results, :fixture_b)
  end

  test "create_fixtures stores module fixtures" do
    {:ok, store_pid} = FixtureStore.start_link

    fixtures = map_fixtures(@test_fixtures)

    results = Imp.create_fixtures(
      [:fixture_a], fixtures, %{module: store_pid}, %{}
    )

    store_fixture = FixtureStore.get_or_create(
      store_pid, :"SomeModule.fixture_a", fn (_) -> make_ref end
    )

    assert store_fixture == results.fixture_a
  end

  test "calling create_fixture twice does not recreate module fixtures" do
    {:ok, store_pid} = FixtureStore.start_link

    fixtures = map_fixtures(@test_fixtures)
    results1 = Imp.create_fixtures([:fixture_a, :fixture_b],
                                   fixtures,
                                   %{module: store_pid},
                                   %{})
    results2 = Imp.create_fixtures([:fixture_a, :fixture_b],
                                   fixtures,
                                   %{module: store_pid},
                                   %{})

    assert results1.fixture_a == results2.fixture_a
    assert results1.fixture_b != results2.fixture_b
  end

  test "un-named deps are not returned by create_fixtures" do
    {:ok, store_pid} = FixtureStore.start_link

    fixtures = map_fixtures(@test_fixtures)
    results = Imp.create_fixtures(
      [:fixture_b], fixtures, %{module: store_pid}, %{}
    )

    refute Map.has_key?(results, :fixture_a)
    assert Map.has_key?(results, :fixture_b)
  end

  @spec map_fixtures([FixtureDef.t]) :: Map.t
  defp map_fixtures(fixtures) do
    fixtures
    |> Enum.map(fn fixture -> {fixture.qualified_name, fixture} end)
    |> Enum.into(%{})
  end
end
