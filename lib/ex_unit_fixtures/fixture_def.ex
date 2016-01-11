defmodule ExUnitFixtures.FixtureDef do
  @moduledoc """
  A struct that stores information about a fixture definition.

  ### Fields

  - `name` - this is the name of the fixture as an atom.
  - `func` - the function that implements this fixture, as `{module, func_name}`
  - `dep_names` - the names of any dependencies this function has as atoms, in
    the order that it accepts them as parameters.
  - `scope` - the scope of the fixture. See `ExUnitFixtures` for more details.
  - `autouse` - whether or not the fixture will automatically be used for all
    tests.
  - `qualified_name` - the name of the fixture & the module it's defined in.
  - `hidden` - whether or not the fixture is "hidden" in the current scope.
    This happens when a fixture has been shadowed by another fixture of the same
    name.
  """

  defstruct [
    name: nil,
    func: nil,
    dep_names: [],
    scope: :function,
    autouse: false,
    qualified_name: nil,
    qualified_dep_names: nil,
    hidden: false
  ]

  @type scope :: :test | :module

  @type t :: %__MODULE__{
    name: :atom,
    func: {:atom, :atom},
    dep_names: [:atom],
    scope: scope,
    autouse: boolean,
    qualified_name: :atom,
    qualified_dep_names: [:atom],
    hidden: boolean
  }

end
