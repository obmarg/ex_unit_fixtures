defmodule ExUnitFixtures.Imp do
  @moduledoc """
  This module provides most of the implementation details of ExUnitFixtures.

  It is seperated out from the main ExUnitFixtures file so the documentation for
  users is not mixed in with a bunch of irrelevant details.
  """

  alias ExUnitFixtures.FixtureDef

  @type fixtures :: %{atom: term}
  @type fixture_dict :: %{atom: FixtureDef.t}

  @doc """
  Creates module scoped fixtures.

  Module scoped fixtures behave slightly differently from test scoped fixtures,
  in that they are always created before every test in a module, regardless of
  whether that test actually requested that fixture or not.

  Note that module scoped fixtures can not depend on the test context, as it has
  not been created at the point they are initialised.
  """
  @spec module_scoped_fixtures(fixture_dict) :: fixtures
  def module_scoped_fixtures(fixture_defs) do
    fixture_defs
    |> module_fixture_names
    |> create_fixtures(fixture_defs, %{}, :module)
  end

  @doc """
  Creates test scoped fixtures for a test, by examining it's test context.

  This should be passed:

  - The `context` of the current test.
  - `fixture_defs` - a map of fixture names to `ExUnitFixtures.FixtureDef`
    structs.

  It will return `context` with the requested fixtures added in, but also with
  any module level fixtures that were not requested stripped out.
  """
  @spec test_scoped_fixtures(%{}, fixture_dict) :: fixtures
  def test_scoped_fixtures(context, fixture_defs) do
    autouse_fixtures = for {_, f} <- fixture_defs, f.autouse, do: f.name

    fixtures = if context[:fixtures] do
      Enum.uniq(autouse_fixtures ++ context[:fixtures])
    else
      autouse_fixtures
    end

    if length(fixtures) != 0 do
      existing_fixtures =
        context
          |> Dict.take(module_fixture_names(fixture_defs))
          |> Dict.put(:context, context)

      test_fixtures = create_fixtures(
        fixtures, fixture_defs, existing_fixtures, :test
      )

      Map.merge(context, test_fixtures)
    else
      context
    end
  end

  @doc """
  Creates fixtures and their dependencies.

  This will create each fixture in `fixtures` using the `FixtureDef` in
  fixture_defs. It takes care to create things in the correct order.

  `existing_fixtures` can be used to pass in fixtures from a higher scope.
  `scope` can be used to ensure fixtures from a higher scope are not recreated.

  It returns a map of fixture name to created fixture.
  """
  @spec create_fixtures([:atom], fixture_dict, fixtures, :atom) :: fixtures
  def create_fixtures(fixtures, fixture_defs, existing_fixtures, scope) do
    fixtures
    |> Enum.map(&resolve_name &1, fixture_defs)
    |> Enum.flat_map(&(fixture_and_dep_info &1, fixture_defs))
    |> Enum.uniq
    |> topsort_fixtures
    |> Enum.filter(fn fixture -> fixture.scope == scope end)
    |> Enum.reduce(existing_fixtures, &create_fixture/2)
    |> Map.take(fixtures)
  end

  @doc """
  Raises an error to report a missing dependency.

  Will attempt to figure out the closest named fixture to the missing
  depdendency and suggest it to the user, to help with typos etc.
  """
  @spec report_missing_dep(:atom, [FixtureDef.t]) :: no_return
  def report_missing_dep(fixture_name, fixture_defs) do
    fixture_name = String.Chars.to_string(fixture_name)
    suggestion =
      fixture_defs
        |> Enum.map(fn f -> f.name end)
        |> Enum.map(&String.Chars.to_string/1)
        |> Enum.sort_by(&(String.jaro_distance &1, fixture_name), &>=/2)
        |> List.first

    err = "Could not find a fixture named #{fixture_name}."
    if suggestion do
      err = err <> " Did you mean #{suggestion}?"
    end
    raise err
  end

  # Figures out the fully qualified name for a fixture.
  @spec resolve_name(:atom, fixture_dict) :: :atom
  defp resolve_name(name, fixture_defs) do
    result = Enum.find(fixture_defs, fn {_, f} ->
      f.name == name and not f.hidden
    end)

    unless result do
      report_missing_dep(name, fixture_defs |> Map.values)
    end

    {_, %{qualified_name: qualified_name}} = result
    qualified_name
  end

  # Gets a fixtures info & all it's dependencies infos.
  # This also does most of the validation of fixtures & their deps.
  @spec fixture_and_dep_info(:atom, fixture_dict) :: [FixtureDef.t]
  defp fixture_and_dep_info(:context, _), do: []
  defp fixture_and_dep_info(fixture_name, fixture_defs) do

    fixture_info = fixture_defs[fixture_name]
    unless fixture_info do
      report_missing_dep(fixture_name, fixture_defs |> Map.values)
    end

    deps = Enum.flat_map(fixture_info.qualified_dep_names,
                         &(fixture_and_dep_info &1, fixture_defs))

    deps ++ [fixture_info]
  end

  # Creates a fixture from it's fixture_info & deps, then inserts it into the
  # created_fixtures map.
  @spec create_fixture(FixtureDef.t, %{}) :: term
  defp create_fixture(fixture_info, created_fixtures) do
    args = for dep_name <- fixture_info.dep_names do
      created_fixtures[dep_name]
    end

    {mod, func} = fixture_info.func
    new_fixture = :erlang.apply(mod, func, args)

    Map.put(created_fixtures, fixture_info.name, new_fixture)
  end

  # Sorts a list of fixtures by their dependencies.
  @spec topsort_fixtures([FixtureDef.t]) :: [FixtureDef.t]
  defp topsort_fixtures(fixtures) do
    graph = :digraph.new([:acyclic])
    try do
      fixtures_to_graph(fixtures, graph)
      for fixture_name <- :digraph_utils.topsort(graph) do
        {_, fixture_info} = :digraph.vertex(graph, fixture_name)
        fixture_info
      end
    after
      :digraph.delete(graph)
    end
  end

  # Takes a list of fixtures, and creates a graph of the fixtures linked to
  # their dependencies using digraph.
  @spec fixtures_to_graph([FixtureDef.t], :digraph.graph) :: nil
  defp fixtures_to_graph(fixtures, graph) do
    for fixture <- fixtures do
      name = fixture.qualified_name
      ^name = :digraph.add_vertex(graph, name, fixture)
    end

    for fixture <- fixtures,
        dep_name <- fixture.qualified_dep_names,
        dep_name != :context do
          [:"$e" | _] = :digraph.add_edge(graph, dep_name,
                                          fixture.qualified_name)
    end

    nil
  end

  # Gets the names of all module fixtures from a fixture_dict.
  @spec module_fixture_names(fixture_dict) :: [:atom]
  defp module_fixture_names(fixture_defs) do
    for {_, f} <- fixture_defs, f.scope == :module, do: f.name
  end

  # Calculates the difference between two lists of terms.
  @spec list_difference([term], [term]) :: [term]
  defp list_difference(x, y) do
    y = Enum.into(y, MapSet.new)

    x |> Enum.into(MapSet.new) |> Set.difference(y) |> Set.to_list
  end
end
