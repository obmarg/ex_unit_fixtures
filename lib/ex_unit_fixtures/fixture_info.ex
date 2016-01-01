defmodule ExUnitFixtures.FixtureInfo do
  @moduledoc """
  Provides a struct that stores information about a fixture.

  ### Fields

  - `name` - this is the name of the fixture as an atom.
  - `func` - the function that implements this fixture, as `{module, func_name}`
  - `dep_names` - the names of any dependencies this function has as atoms, in
    the order that it accepts them as parameters.
  - `scope` - the scope of the fixture. See `ExUnitFixtures` for more details.
  - `autouse` - whether or not the fixture will automatically be used for all
    tests.
  """

  defstruct [
    name: nil,
    func: nil,
    dep_names: [],
    scope: :function,
    autouse: false
  ]

  @type scope :: :test | :module

  @type t :: %__MODULE__{
    name: :atom,
    func: {:atom, :atom},
    dep_names: [:atom],
    scope: scope,
    autouse: boolean
  }

end
