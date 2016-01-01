defmodule ExUnitFixtures.Imp do
  @moduledoc """
  This module provides most of the implementation details of ExUnitFixtures.

  It is seperated out from the main ExUnitFixtures file so the documentation for
  users is not mixed in with a bunch of irrelevant details.
  """

  alias ExUnitFixtures.FixtureInfo

  @type fixtures :: %{atom: term}
  @type fixture_infos :: %{atom: FixtureInfo.t}

  @doc """
  Creates module scoped fixtures.

  Module scoped fixtures behave slightly differently from test scoped fixtures,
  in that they are always created before every test in a module, regardless of
  whether that test actually requested that fixture or not.

  Note that module scoped fixtures can not depend on the test context, as it has
  not been created at the point they are initialised.
  """
  @spec module_scoped_fixtures(fixture_infos) :: fixtures
  def module_scoped_fixtures(fixture_infos) do
    fixture_infos
    |> module_fixture_names
    |> create_fixtures(fixture_infos, %{})
  end

  @doc """
  Creates test scoped fixtures for a test, by examining it's test context.

  This should be passed:

  - The `context` of the current test.
  - `fixture_infos` - a map of fixture names to `ExUnitFixtures.FixtureInfo`
    structs.

  It will return `context` with the requested fixtures added in, but also with
  any module level fixtures that were not requested stripped out.
  """
  @spec test_scoped_fixtures(%{}, fixture_infos) :: fixtures
  def test_scoped_fixtures(context, fixture_infos) do
    module_fixtures = module_fixture_names(fixture_infos)
    autouse_fixtures = for {_, f} <- fixture_infos, f.autouse, do: f.name

    fixtures = if context[:fixtures] do
      Enum.uniq(autouse_fixtures ++ context[:fixtures])
    else
      autouse_fixtures
    end

    if length(fixtures) != 0 do
      existing_fixtures =
        context
          |> Dict.take(module_fixtures)
          |> Dict.put(:context, context)

      test_fixtures =
        fixtures
          |> list_difference(module_fixtures)
          |> create_fixtures(fixture_infos, existing_fixtures)

      Map.merge(context, test_fixtures)
    else
      context
    end
  end

  @doc """
  Creates fixtures and their dependencies.

  This will create each fixture in `fixtures` using the `FixtureInfo` in
  fixture_infos. It takes care to create things in the correct order.

  It returns a map of fixture name to created fixture.
  """
  @spec create_fixtures([:atom], fixture_infos, fixtures) :: fixtures
  def create_fixtures(fixtures, fixture_infos, existing_fixtures) do
    fixtures
    |> Enum.flat_map(&(fixture_and_dep_info &1, fixture_infos))
    |> Enum.uniq
    |> topsort_fixtures
    |> Enum.reduce(existing_fixtures, &create_fixture/2)
    |> Map.take(fixtures)
  end

  @spec fixture_and_dep_info(:atom, fixture_infos) :: [FixtureInfo.t]
  defp fixture_and_dep_info(:context, _), do: []
  defp fixture_and_dep_info(fixture_name, fixture_infos) do
    # Gets a fixtures info & all it's dependencies infos.
    # This also does most of the validation of fixtures & their deps.

    fixture_info = fixture_infos[fixture_name]
    unless fixture_info do
      fixture_name = String.Chars.to_string(fixture_name)
      suggestion =
        fixture_infos
        |> Map.keys
        |> Enum.map(&String.Chars.to_string/1)
        |> Enum.sort_by(&(String.jaro_distance &1, fixture_name), &>=/2)
        |> List.first

      err = "Could not find a fixture named #{fixture_name}."
      if suggestion do
        err = err <> " Did you mean #{suggestion}?"
      end
      raise err
    end

    deps = Enum.flat_map fixture_info.dep_names, fn (child_name) ->
      deps = fixture_and_dep_info(child_name, fixture_infos)
      :ok = validate_deps(fixture_info, deps)
      deps
    end

    deps ++ [fixture_info]
  end

  @spec validate_deps(FixtureInfo.t, [FixtureInfo.t]) :: :ok
  defp validate_deps(%{scope: :module, name: name}, deps) do
    for dep <- deps, dep.scope == :test do
      raise """
      Mis-matched scopes:
      #{name} is scoped to the test module
      #{dep.name} is scoped to the test.
      But #{name} depends on #{dep.name}
      """
    end
    :ok
  end
  defp validate_deps(_, _), do: :ok

  @spec create_fixture(:atom, %{}) :: term
  defp create_fixture(fixture_info, created_fixtures) do
    # Creates a fixture from it's fixture_info & deps, then inserts it into the
    # created_fixtures map.
    args = for dep_name <- fixture_info.dep_names do
      created_fixtures[dep_name]
    end

    {mod, func} = fixture_info.func
    new_fixture = :erlang.apply(mod, func, args)

    Map.put(created_fixtures, fixture_info.name, new_fixture)
  end

  @spec topsort_fixtures([FixtureInfo.t]) :: [FixtureInfo.t]
  defp topsort_fixtures(fixtures) do
    # Sorts a list of fixtures by their dependencies.
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

  @spec fixtures_to_graph([FixtureInfo.t], :digraph.graph) :: nil
  defp fixtures_to_graph(fixtures, graph) do
    for fixture <- fixtures do
      name = fixture.name
      ^name = :digraph.add_vertex(graph, name, fixture)
    end

    for fixture <- fixtures,
        dep_name <- fixture.dep_names,
        dep_name != :context do
          [:"$e" | _] = :digraph.add_edge(graph, dep_name, fixture.name)
    end

    nil
  end

  @spec module_fixture_names(fixture_infos) :: [:atom]
  defp module_fixture_names(fixture_infos) do
    for {_, f} <- fixture_infos, f.scope == :module, do: f.name
  end

  @spec list_difference([term], [term]) :: [term]
  defp list_difference(x, y) do
    y = Enum.into(y, MapSet.new)

    x |> Enum.into(MapSet.new) |> Set.difference(y) |> Set.to_list
  end
end
