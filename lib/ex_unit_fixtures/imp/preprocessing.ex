defmodule ExUnitFixtures.Imp.Preprocessing do
  @moduledoc """
  Provides functions that pre-process fixtures at compile time.

  Most of the functions provide some sort of transformation or validation
  process that we need to do on fixtures at compile time.
  """

  alias ExUnitFixtures.FixtureDef

  @type fixture_dict :: %{atom: FixtureDef.t}

  @doc """
  Checks there are no fixtures named `fixture_name` already in `fixtures`.

  Raises an error if any clashes are found.
  """
  def check_clashes(fixture_name, fixtures) do
    if Enum.find(fixtures, fn f -> f.name == fixture_name end) != nil do
      raise "There is already a fixture named #{fixture_name} in this module."
    end
  end

  @doc """
  Pre-processes the defined & imported fixtures in a module.

  This will take the list of fixtures that have been defined, resolve their
  dependencies and produce a map of those dependencies merged with any imported
  dependencies.

  The map will use fully qualified fixture names for keys.
  """
  @spec preprocess_fixtures([FixtureDef.t],
                            [:atom] | fixture_dict) :: fixture_dict
  def preprocess_fixtures(local_fixtures,
                          imported_modules) when is_list(imported_modules) do
    imported_fixtures = fixtures_from_modules(imported_modules)
    preprocess_fixtures(local_fixtures, imported_fixtures)
  end

  def preprocess_fixtures(local_fixtures, imported_fixtures) do
    resolved_locals =
      for f <- resolve_dependencies(local_fixtures, imported_fixtures),
      into: %{},
      do: {f.qualified_name, f}

    local_fixtures
    |> hide_fixtures(imported_fixtures)
    |> Dict.merge(resolved_locals)
  end

  @doc """
  Resolves dependencies for fixtures in a module.

  Replaces the unqualified dep_names in a FixtureDef with qualified names.
  """
  @spec resolve_dependencies([FixtureDef.t], fixture_dict) :: [FixtureDef.t]
  def resolve_dependencies(local_fixtures, imported_fixtures) do
    visible_fixtures =
      for {_, f} <- imported_fixtures,
      !f.hidden,
      into: %{},
      do: {f.name, f}

    all_fixtures = Map.merge(
      visible_fixtures,
      (for f <- local_fixtures, into: %{}, do: {f.name, f})
    )

    for fixture <- local_fixtures do
      resolved_deps = for dep <- fixture.dep_names do
        resolve_dependency(dep, fixture, all_fixtures, visible_fixtures)
      end
      %{fixture | qualified_dep_names: resolved_deps}
    end
  end

  @spec resolve_dependency(:atom, FixtureDef.t,
                           fixture_dict, fixture_dict) :: :atom
  defp resolve_dependency(:context, _, _, _) do
    # Special case the ExUnit.Case context
    :context
  end
  defp resolve_dependency(dep_name, fixture,
                          all_fixtures, visible_fixtures) do
    resolved_dep = if dep_name == fixture.name do
      visible_fixtures[dep_name]
    else
      all_fixtures[dep_name]
    end
    unless resolved_dep do
      ExUnitFixtures.Imp.report_missing_dep(dep_name,
                                            all_fixtures |> Map.values)
    end
    validate_dep(fixture, resolved_dep)
    resolved_dep.qualified_name
  end

  @spec hide_fixtures([FixtureDef.t], fixture_dict) :: fixture_dict
  defp hide_fixtures(local_fixtures, imported_fixtures) do
    # Hides any fixtures in imported_fixtures that have been shadowed by
    # local_fixtures.
    names_to_hide = for f <- local_fixtures, into: MapSet.new, do: f.name

    for {name, f} <- imported_fixtures, into: %{} do
      if Set.member?(names_to_hide, f.name) do
        {name, %{f | hidden: true}}
      else
        {name, f}
      end
    end
  end

  @spec fixtures_from_modules([:atom]) :: fixture_dict
  defp fixtures_from_modules(modules) do
    imported_fixtures = for module <- modules, do: module.fixtures
    Enum.reduce imported_fixtures, %{}, &Dict.merge/2
  end


  @spec validate_dep(FixtureDef.t, FixtureDef.t) :: :ok | no_return
  defp validate_dep(%{scope: :module, name: fixture_name},
                    %{scope: :test, name: dep_name}) do
    raise """
      Mis-matched scopes:
      #{fixture_name} is scoped to the test module
      #{dep_name} is scoped to the test.
      But #{fixture_name} depends on #{dep_name}
    """
  end
  defp validate_dep(_fixture, _resolved_dep), do: :ok
end
