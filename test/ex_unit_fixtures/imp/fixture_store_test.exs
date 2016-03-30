defmodule ExUnitFixtures.Imp.FixtureStoreTest do
  use ExUnit.Case

  alias ExUnitFixtures.Imp.FixtureStore

  setup do
    {:ok, pid} = FixtureStore.start_link()

    {:ok, %{store: pid}}
  end

  test "get_or_create only creates once", %{store: store} do
    entry1 = FixtureStore.get_or_create(store, :test, fn (_) -> make_ref end)
    entry2 = FixtureStore.get_or_create(store, :test, fn (_) -> make_ref end)
    assert entry1 == entry2
  end

  test "get_or_create disambiguates by key", %{store: store} do
    entry1 = FixtureStore.get_or_create(store, :test, fn (_) -> make_ref end)
    entry2 = FixtureStore.get_or_create(store, :test2, fn (_) -> make_ref end)
    assert entry1 != entry2
  end

  test "create_fun is passed existing fixtures", %{store: store} do
    entry1 = FixtureStore.get_or_create(store, :test, fn (existing) ->
      assert Map.keys(existing) == []
      make_ref
    end)

    entry2 = FixtureStore.get_or_create(store, :test2, fn (existing) ->
      assert existing.test == entry1
      make_ref
    end)

    assert entry1 != entry2
  end
end
