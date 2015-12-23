# ExunitFixtures

A library for defining test fixtures for ExUnit tests.

Inspired by the fixtures in pythons py.test.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add exunit_fixtures to your list of dependencies in `mix.exs`:

        def deps do
          [{:exunit_fixtures, "~> 0.0.1"}]
        end

  2. Ensure exunit_fixtures is started before your application:

        def application do
          [applications: [:exunit_fixtures]]
        end
