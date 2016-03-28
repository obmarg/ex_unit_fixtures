defmodule FirstFixtures do
  use ExUnitFixtures.FixtureModule

  deffixture overridable do
    :initial
  end

  deffixture overridable2 do
    :from_first_fixtures
  end
end

defmodule Fixtures do
  use ExUnitFixtures.FixtureModule
  use FirstFixtures

  deffixture simple do
    :simple
  end

  deffixture fixture_that_uses_overridable(overridable) do
    overridable
  end

  deffixture overridable(overridable) do
    {:second, overridable}
  end

  deffixture overridable2 do
    :from_fixtures
  end
end

defmodule FixtureModuleTest do
  use Fixtures
  use ExUnitFixtures
  use ExUnit.Case

  deffixture overridable2(overridable2) do
    {:in_test, overridable2}
  end

  test "that a test without fixtures works", context do
    refute Dict.has_key?(context, :simple)
  end

  test "that we have an imported_fixtures module attribute" do
    assert length(@fixture_modules) > 0
  end

  @tag fixtures: [:simple]
  test "that we can import fixtures from the fixture module", context do
    assert context.simple == :simple
  end

  @tag fixtures: [:overridable]
  test "we can override fixtures from other modules", context do
    assert context.overridable == {:second, :initial}
  end

  @tag fixtures: [:fixture_that_uses_overridable]
  test "depending on an overridden fixture gets the current version", context do
    assert context.fixture_that_uses_overridable == {:second, :initial}
  end

  @tag fixtures: [:overridable2]
  test "that we can override locally", context do
    {first, _} = context.overridable2
    assert first == :in_test
  end

  @tag fixtures: [:overridable2]
  test "that we can hide fixtures without using them", context do
    {_, second} = context.overridable2
    assert second == :from_fixtures
  end
end
