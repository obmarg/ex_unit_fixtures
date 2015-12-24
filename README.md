# ExUnitFixtures

A library for defining test fixtures for ExUnit tests. Inspired by py.test
fixtures.

It's pretty normal for tests to share various bits of setup code. Whether it's
to add some models to a database, setup a connection to an external service or
something else entirely.

ExUnit provides the `setup` and `setup_all` functions that can be used for
this.  These work for the simplest cases, but have a couple of drawbacks:

- The setup code will run for all tests, even if the test does not need it.
- Sharing setup code between modules requires extracting it out into a function.

ExUnitFixtures attempts to solve that. It provides a way to define a fixture,
which can be any bit of setup code that a test might require. Each of the tests
in a file can then list the fixtures they require and have them injected into
the tests context.

For example:

    defmodule MyTests
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

Fixtures can depend on other fixtures, by naming a parameter after that fixture:

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

If you need to do some teardown work for a fixture you can use the ExUnit
`on_exit` function:

    deffixture database do
      # Setup the database
      on_exit fn ->
        # Tear down the database
      end
    end

## Installation

  1. Add exunit_fixtures to your list of dependencies in `mix.exs`:

        def deps do
          [{:exunit_fixtures, github: "obmarg/exunit_fixtures", only: [:test]}]
        end
