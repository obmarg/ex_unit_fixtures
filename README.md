# ExUnitFixtures

A library for defining test fixtures for ExUnit tests. Inspired by py.test
fixtures.

#### What are Fixtures?

Fixtures in ExUnitFixtures are just functions that will be run before a test.
They can be used to setup the tests environment somehow, or provide the test
with some data that it requires.

ExUnit provides the `setup` and `setup_all` functions that can be used for
this.  These work well for simpler cases, but have a couple of drawbacks:

- The setup code will run for all tests, even if the test does not need it.
- Sharing setup code between modules requires extracting it out into a function.

ExUnitFixtures attempts to solve that. It provides a way to define a fixture,
which can be any bit of setup code that a test might require. Each of the tests
in a file can then list the fixtures they require and have them injected into
the tests context.

## Installation

  1. Add ex_unit_fixtures to your list of dependencies in `mix.exs`:

        def deps do
          [{:ex_unit_fixtures, "~> 0.2.0", only: [:test]}]
        end

## Documentation

The documentation can be found on hexdocs.pm:
http://hexdocs.pm/ex_unit_fixtures/ExUnitFixtures.html

## Example

For example, lets say some of your tests required a model named `my_model`, you
need to define the fixture using `deffixture` and then tag your test to say it
requires this fixture:

    defmodule MyTests do
      use ExUnitFixtures
      use ExUnit.Case

      deffixture my_model do
        # Create a model somehow...
        %{test: 1}
      end

      @tag fixtures: [:my_model]
      test "that we have some fixtures", context do
        assert context.my_model.test == 1
      end
    end

More details can be found in
[the documentation](http://hexdocs.pm/ex_unit_fixtures/ExUnitFixtures.html).
