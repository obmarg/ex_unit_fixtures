defmodule AutoLoadTest do
  use ExUnitFixtures
  use ExUnitFixtures.AutoLoad
  use ExUnit.Case

  test "that we have our top-level fixture module" do
    assert TopLevelFixtures.fixtures != nil
  end

  test "that we have our current directory fixture module" do
    assert AutoLoadFixtures.fixtures != nil
  end
end
