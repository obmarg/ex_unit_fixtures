defmodule SimpleEctoTest do
  use ExUnitFixtures
  use ExUnit.Case
  import Ecto.Query, only: [from: 2]

  @tag fixtures: [:countries]
  test "can query for countries" do
    results = SimpleEcto.Repo.all from p in Country, select: p.name
    assert Enum.sort(results) == ["Canada", "United Kingdom"]
  end

  @tag fixtures: [:cities]
  test "can query for cities" do
    results = SimpleEcto.Repo.all from p in City, select: p.name
    assert Enum.sort(results) == ["Edinburgh", "London", "Vancouver"]
  end

end
