defmodule ExUnitFixtures.Imp do
  @moduledoc false
  # This module provides most of the implementation details of ExUnitFixtures.
  # It is seperated out from the main ExUnitFixtures file so the documentation
  # for users is not mixed in with a bunch of irrelevant details.

  alias ExUnitFixtures.FixtureDef
  alias ExUnitFixtures.Imp.FixtureStore

  @type fixtures :: %{atom: term}
  @type fixture_dict :: %{atom: FixtureDef.t}

  @doc """
  Creates fixtures & their deps for a test.

  This will create each fixture in `fixture_names` using the corresponding entry
  in `fixture_defs`.

  It will make use of the fixture stores in `store_pids` to fetch & store any
  module scoped fixtures.
  """
  @spec create_fixtures([:atom], fixture_dict, Map.t, Map.t) :: fixtures
  def create_fixtures(fixture_names, fixture_defs, store_pids, test_context) do
    autouse_fixtures = for {_, f} <- fixture_defs, f.autouse, do: f.name
    fixture_names = fixture_names ++ autouse_fixtures

    grouped = fixture_names |> resolve_fixtures(fixture_defs) |> group_by_scope

    fixtures =
      %{}
      |> get_or_create_fixtures(grouped.session, store_pids.session)
      |> get_or_create_fixtures(grouped.module, store_pids.module)
      |> Map.put(:context, test_context)

    grouped.test
    |> Enum.reduce(fixtures, fn (fixture_def, fixtures) ->
      Map.put(
        fixtures, fixture_def.qualified_name,
        create_fixture(fixture_def, fixtures)
      )
    end)
    |> requested_fixtures(fixture_names, fixture_defs)
  end

  # Gets or creates some fixtures from the store at `store_pid`
  # `outer_fixtures` can be used to pass fixtures from a higher scope.
  @spec get_or_create_fixtures([FixtureDef.t], pid, Map.t) :: Map.t
  defp get_or_create_fixtures(outer_fixtures, fixture_defs, store_pid) do
    for fixture_def <- fixture_defs, into: outer_fixtures do
      fixture = FixtureStore.get_or_create(
        store_pid, fixture_def.qualified_name,
        &(create_fixture fixture_def, Map.merge(outer_fixtures, &1))
      )

      {fixture_def.qualified_name, fixture}
    end
  end

  # Takes a map of qualified fixture names -> fixtures, filters it to only the
  # requested fixtures, and returns a map with the non-qualified names.
  @spec requested_fixtures([:atom], [FixtureDef.t], Map.t) :: Map.t
  defp requested_fixtures(fixtures, fixture_names, fixture_defs) do
    name_map = for name <- fixture_names, into: %{} do
      {resolve_name(name, fixture_defs), name}
    end

    fixtures
    |> Map.take(Map.keys(name_map))
    |> Enum.map(fn {k, v} -> {name_map[k], v} end)
    |> Enum.into(%{})
  end

  @doc """
  Resolves a list of fixture names into a list of fixture defs.

  This list will include any dependencies of the required fixtures, and will be
  returned in the correct order for instantiation.
  """
  @spec resolve_fixtures([:atom], fixture_dict) :: [FixtureDef.t]
  def resolve_fixtures(fixture_names, fixture_defs) do
    fixture_names
    |> Enum.map(&resolve_name &1, fixture_defs)
    |> Enum.flat_map(&(fixture_and_dep_info &1, fixture_defs))
    |> Enum.uniq
    |> topsort_fixtures
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
    err = err <> if suggestion, do: " Did you mean #{suggestion}?", else: ""

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
    fixture_def = fixture_defs[fixture_name]
    unless fixture_def do
      report_missing_dep(fixture_name, fixture_defs |> Map.values)
    end

    deps = Enum.flat_map(fixture_def.qualified_dep_names,
                         &(fixture_and_dep_info &1, fixture_defs))

    deps ++ [fixture_def]
  end

  # Creates a fixture from it's fixture_def & deps.
  @spec create_fixture(FixtureDef.t, Map.t) :: term
  defp create_fixture(fixture_def, created_fixtures) do
    args = for dep_name <- fixture_def.qualified_dep_names do
      created_fixtures[dep_name]
    end

    {mod, func} = fixture_def.func
    :erlang.apply(mod, func, args)
  end

  # Sorts a list of fixtures by their dependencies.
  @spec topsort_fixtures([FixtureDef.t]) :: [FixtureDef.t]
  defp topsort_fixtures(fixtures) do
    graph = :digraph.new([:acyclic])
    try do
      fixtures_to_graph(fixtures, graph)
      for fixture_name <- :digraph_utils.topsort(graph) do
        {_, fixture_def} = :digraph.vertex(graph, fixture_name)
        fixture_def
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

  # Groups a list of fixtures by scope.
  # Unlike Enum.group_by, this will preserve ordering.
  @spec group_by_scope([FixtureInfo.t]) :: %{}
  defp group_by_scope(fixtures) do
    [:test, :module, :session]
    |> Enum.map(fn scope ->
        {scope, (for fixture <- fixtures, fixture.scope == scope, do: fixture)}
      end)
    |> Enum.into(%{})
  end
end
