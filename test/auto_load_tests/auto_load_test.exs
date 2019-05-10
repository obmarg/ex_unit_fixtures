defmodule AutoLoadTest do
  use ExUnitFixtures
  use ExUnit.Case, async: true
  ExUnit.Case.register_attribute __MODULE__, :fixtures

  deffixture local(fixture_that_uses_top) do
    {fixture_that_uses_top, :local}
  end

  test "that we have our top-level fixture module" do
    assert TopLevelFixtures.fixtures != nil
  end

  test "that we have our current directory fixture module" do
    assert AutoLoadFixtures.fixtures != nil
  end

  @fixtures :top_level_fixture
  test "that we have access to top-level fixtures", context do
    assert context.top_level_fixture == :top
  end

  @fixtures :not_top_level_fixture
  test "we have access to not_top_level_fixture", context do
    assert context.not_top_level_fixture == :not_top
  end

  @fixtures {:local, :fixture_that_uses_top}
  test "local fixtures can import parent fixtures as tuple", context do
    assert context.fixture_that_uses_top == {:top, :middle}
    assert context.local == {{:top, :middle}, :local}
  end

  @fixtures [:local, :fixture_that_uses_top]
  test "local fixtures can import parent fixtures as list", context do
    assert context.fixture_that_uses_top == {:top, :middle}
    assert context.local == {{:top, :middle}, :local}
  end
end
