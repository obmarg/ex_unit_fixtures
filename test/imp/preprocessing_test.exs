defmodule PreprocessingTest do
  use ExUnit.Case

  alias ExUnitFixtures.FixtureDef

  import ExUnitFixtures.Imp.Preprocessing

  test "check_clashes errors if there's a clash" do
    assert_raise RuntimeError, fn ->
      check_clashes(:test, [%FixtureDef{name: :test},
                            %FixtureDef{name: :nottest}])
    end
  end

  test "check_clashes passes if there's not a clash" do
    check_clashes(:test, [%FixtureDef{name: :nottest}])
  end

  test "preprocess_fixtures with no imported modules" do
    input = [%FixtureDef{name: :fixture_one,
                         qualified_name: :"Test.fixture_one"},
             %FixtureDef{name: :fixture_two,
                         dep_names: [:fixture_one],
                         qualified_name: :"Test.fixture_two"}]
    output = preprocess_fixtures(input, [])

    assert output[:"Test.fixture_one"] != nil
    assert output[:"Test.fixture_two"] != nil
    assert Dict.size(output) == 2

    assert output[:"Test.fixture_one"].dep_names == []
    assert output[:"Test.fixture_one"].qualified_dep_names == []
    assert output[:"Test.fixture_one"].hidden == false

    assert output[:"Test.fixture_two"].dep_names == [:fixture_one]
    assert output[:"Test.fixture_two"].qualified_dep_names == [:"Test.fixture_one"]
    assert output[:"Test.fixture_two"].hidden == false
  end

  test "preprocess_fixtures with an imported module and no clash" do
    imported_fixtures = %{
      :"Fixtures.fixture_one" => %FixtureDef{
        name: :fixture_one,
        qualified_name: :"Fixtures.fixture_one"
      }
    }
    local_fixtures = [%FixtureDef{name: :fixture_two,
                                  dep_names: [:fixture_one],
                                  qualified_name: :"Test.fixture_two"}]

    output = preprocess_fixtures(local_fixtures, imported_fixtures)

    assert output[:"Fixtures.fixture_one"] != nil
    assert output[:"Test.fixture_two"] != nil
    assert Dict.size(output) == 2

    assert output[:"Fixtures.fixture_one"].hidden == false

    assert output[:"Test.fixture_two"].qualified_dep_names == [
      :"Fixtures.fixture_one"
    ]
    assert output[:"Test.fixture_two"].hidden == false
  end

  test "preprocess_fixtures hides clashes" do
    imported_fixtures = %{
      :"Fixtures.fixture_one" => %FixtureDef{
        name: :fixture_one,
        qualified_name: :"Fixtures.fixture_one"
      }
    }
    local_fixtures = [%FixtureDef{name: :fixture_one,
                                  dep_names: [:fixture_one],
                                  qualified_name: :"Test.fixture_one"}]

    output = preprocess_fixtures(local_fixtures, imported_fixtures)

    assert output[:"Fixtures.fixture_one"] != nil
    assert output[:"Test.fixture_one"] != nil
    assert Dict.size(output) == 2

    assert output[:"Fixtures.fixture_one"].hidden == true

    assert output[:"Test.fixture_one"].qualified_dep_names == [
      :"Fixtures.fixture_one"
    ]
    assert output[:"Test.fixture_one"].hidden == false
  end

  test "resolve_dependencies with missing deps fails" do
    assert_raise RuntimeError, ~r/Could not find a fixture named missing/, fn ->
      resolve_dependencies(
        [%FixtureDef{name: :test, dep_names: [:missing]}], %{}
      )
    end
  end

  test "resolve_dependencies suggests other fixtures when missing" do
    assert_raise RuntimeError, ~r/Did you mean test\?$/, fn ->
      resolve_dependencies(
        [%FixtureDef{name: :test, dep_names: [:missing]}], %{}
      )
    end
  end

  test "resolve_dependencies errors if module scope depends on test scope" do
    fixture_defs = [%FixtureDef{name: :mod, scope: :module,
                                dep_names: [:test]},
                    %FixtureDef{name: :test, scope: :test}]

    assert_raise RuntimeError, ~r/scoped to the test/, fn ->
      resolve_dependencies(fixture_defs, %{})
    end
  end
end
