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

  1. Add exunit_fixtures to your list of dependencies in `mix.exs`:

        def deps do
          [{:ex_unit_fixtures, github: "obmarg/ex_unit_fixtures", only: [:test]}]
        end

## Using ExUnit

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
    
#### Fixtures with dependencies

Fixtures can also depend on other fixtures by naming a parameter after that
fixture. For example, if you needed to setup a database instance before creating
some models:

    deffixture database do
      # set up the database somehow...
    end

    deffixture my_model(database) do
      # use the database to insert a model
    end

    @tag fixtures: [:my_model]
    test "something" do
      # Test
    end

In the sample above, we have 2 fixtures: one which creates the database and
another which inserts a model into that database. The test function depends on
`my_model` which depends on the database. ExUnitFixtures knows this, and takes
care of setting up the database and passing it in to `my_model`.

#### Tearing down Fixtures

If you need to do some teardown work for a fixture you can use the ExUnit
`on_exit` function:

    defmodule TestWithTearDowns do
      use ExUnitFixtures
      use ExUnit.Case

      deffixture database do
        # Setup the database
        on_exit fn ->
          # Tear down the database
          nil
        end
      end
    end
