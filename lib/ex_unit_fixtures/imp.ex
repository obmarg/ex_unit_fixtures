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

    %{test: test_scoped, module: module_scoped} =
      fixture_names
      |> resolve_fixtures(fixture_defs)
      |> group_by_scope

    # Create/get module scoped fixtures
    fixtures = Enum.reduce(module_scoped, %{}, fn (fixture_info, fixtures) ->
      Map.put(
        fixtures, fixture_info.qualified_name,
        get_or_create_fixture(fixture_info, store_pids.module)
      )
    end)

    # Add test context and create test scoped fixtures
    fixtures = Map.put(fixtures, :context, test_context)
    fixtures = Enum.reduce(test_scoped, fixtures, fn (fixture_info, fixtures) ->
      Map.put(
        fixtures, fixture_info.qualified_name,
        create_fixture(fixture_info, fixtures)
      )
    end)

    # Build up a map of names -> resolved_name
    name_map =
      fixture_names
      |> Enum.map(fn (name) -> {resolve_name(name, fixture_defs), name} end)
      |> Enum.into(%{})

    # Use that map to produce our actual output...
    fixtures
    |> Map.take(Map.keys(name_map))
    |> Enum.map(fn {k, v} -> {name_map[k], v} end)
    |> Enum.into(%{})
  end

  @spec get_or_create_fixture(FixtureDef.t, pid) :: any
  defp get_or_create_fixture(fixture_info, store_pid) do
    FixtureStore.get_or_create(
      store_pid, fixture_info.qualified_name,
      &(create_fixture fixture_info, &1)
    )
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

  # Creates a fixture from it's fixture_info & deps.
  @spec create_fixture(FixtureDef.t, Map.t) :: term
  defp create_fixture(fixture_info, created_fixtures) do
    args = for dep_name <- fixture_info.qualified_dep_names do
      created_fixtures[dep_name]
    end

    {mod, func} = fixture_info.func
    :erlang.apply(mod, func, args)
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

  # Groups a list of fixtures by scope.
  # Unlike Enum.group_by, this will preserve ordering.
  @spec group_by_scope([FixtureInfo.t]) :: %{}
  def group_by_scope(fixtures) do
    [:test, :module]
    |> Enum.map(fn scope ->
        {scope, (for fixture <- fixtures, fixture.scope == scope, do: fixture)}
      end)
    |> Enum.into(%{})
  end
end
