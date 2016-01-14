defmodule ModuleStoreTestFixtures do
  use ExUnitFixtures.FixtureModule
end

defmodule ModuleStoreTestFixtures2 do
  use ExUnitFixtures.FixtureModule
end

defmodule ModuleStoreTest do
  use ExUnit.Case

  alias ExUnitFixtures.Imp.ModuleStore

  test "that we can find modules by file" do
    assert ModuleStore.find_file(__ENV__.file) == [
      ModuleStoreTestFixtures2, ModuleStoreTestFixtures
    ]
  end

  test "that we can find files by modules" do
    assert ModuleStore.find_module(ModuleStoreTestFixtures) == __ENV__.file
    assert ModuleStore.find_module(ModuleStoreTestFixtures2) == __ENV__.file
  end
end
