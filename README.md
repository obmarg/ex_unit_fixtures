# ExUnitFixtures

A library for defining modular dependencies (fixtures) for ExUnit tests.

#### What are Fixtures?

Fixtures in ExUnitFixtures are just functions that are run before a test.

They can be used to setup the tests environment somehow, or provide the test
with some data that it requires. Similar in purpose to `setup` & `setup_all` but
more powerful:

- Tests explicitly list what fixtures they require, ensuring that no
  un-neccesary setup work is done.
- Fixtures may be shared across many tests in a project.
- Fixtures may depend on or override other fixtures, allowing core fixtures to
  be used & customised as each subsystem or test module requires.

## Installation

  1. Add ex_unit_fixtures to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:ex_unit_fixtures, "~> 0.3.1", only: [:test]}]
end
```

## Documentation

The documentation can be found on hexdocs.pm:
http://hexdocs.pm/ex_unit_fixtures/ExUnitFixtures.html

## Example

Say some of your tests required a model named `my_model`. You should define a
fixture fixture using `deffixture`, then tag your test to say it requires this
fixture:

```elixir
defmodule MyTests do
  use ExUnitFixtures
  use ExUnit.Case
  ExUnit.Case.register_attribute __MODULE__, :fixtures

  deffixture my_model do
    # Create a model somehow...
    %{test: 1}
  end

  @fixtures: :my_model
  test "that we have some fixtures", context do
    assert context.my_model.test == 1
  end
end
```

More details can be found in
[the documentation](http://hexdocs.pm/ex_unit_fixtures/ExUnitFixtures.html).


### Examples in the wild.

- [Vassal](https://github.com/obmarg/vassal) makes use of ExUnitFixtures in
  it's integration tests.
- I have played around with converting the tests for
  [Sqlitex](https://github.com/obmarg/sqlitex/tree/ex_unit_fixtures) to use
  ExUnitFixtures.  (This hasn't been PRd, it's just another example).
