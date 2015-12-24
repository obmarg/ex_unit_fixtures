defmodule ExUnitFixtures do
  @moduledoc """
  A library for declaring & using fixtures in ExUnit.
  """

  defmodule FixtureInfo do
    @moduledoc """
    Stores information about a fixture.
    """

    defstruct name: nil, func: nil, dep_names: []

    @type t :: %__MODULE__{
      name: :atom,
      func: {:atom, :atom},
      dep_names: [:atom]
    }
  end

  @doc """
  Defines a fixture.
  """
  defmacro deffixture({name, info, params}, body) do
    if name == :context do
      raise """
      The name context is reserved for the ExUnit context.
      It may not be used for fixtures.
      """
    end

    create_name = :"fixture_create_#{name}"
    dep_names = for {dep_name, _, _} <- params || [] do
      dep_name
    end

    quote do
      def unquote({create_name, info, params}), unquote(body)

      @fixtures %FixtureInfo{name: unquote(name),
                             func: {__MODULE__, unquote(create_name)},
                             dep_names: unquote(dep_names)}
    end
  end

  defmacro __using__(_opts) do
    quote do
      if is_list(Module.get_attribute(__MODULE__, :ex_unit_tests)) do
        raise "`use ExUnitFixtures` must come before `use ExUnit.Case`"
      end
      Module.register_attribute __MODULE__, :fixtures, accumulate: true
      @before_compile ExUnitFixtures

      import ExUnitFixtures, only: [deffixture: 2]
    end
  end

  defmacro __before_compile__(_) do
    quote do
      setup context do
        fixtures = for fixture <- @fixtures, into: %{} do
          {fixture.name, fixture}
        end

        {:ok, ExUnitFixtures.fixtures_for_context(context, fixtures)}
      end
    end
  end

  @doc """
  Creates the required fixtures for a given test context.
  """
  @spec fixtures_for_context(%{}, %{}) :: %{}
  def fixtures_for_context(context, all_fixtures) do
    if context[:fixtures] do
      fixtures =
        context.fixtures
          |> Enum.flat_map(&(fixture_and_deps &1, all_fixtures))
          |> Enum.uniq
          |> topsort_fixtures
          |> Enum.reduce(%{context: context}, &create_fixture/2)
          |> Map.take(context.fixtures)

      Map.merge(context, fixtures)
    else
      context
    end
  end

  @spec fixture_and_deps(:atom, %{atom: FixtureInfo.t}) :: [FixtureInfo.t]
  defp fixture_and_deps(:context, _), do: []
  defp fixture_and_deps(fixture_name, all_fixtures) do
    # Gets a fixture & it's dependencies from all the potential fixtures.
    fixture_info = all_fixtures[fixture_name]
    unless fixture_info do
      fixture_name = String.Chars.to_string(fixture_name)
      suggestion =
        all_fixtures
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

    deps = Enum.flat_map(fixture_info.dep_names,
                         &(fixture_and_deps &1, all_fixtures))
    deps ++ [fixture_info]
  end

  @spec create_fixture(:atom, %{}) :: term
  defp create_fixture(fixture_info, created_fixtures) do
    args = for dep_name <- fixture_info.dep_names do
      created_fixtures[dep_name]
    end

    {mod, func} = fixture_info.func
    new_fixture = :erlang.apply(mod, func, args)

    Map.put(created_fixtures, fixture_info.name, new_fixture)
  end

  @spec topsort_fixtures([FixtureInfo.t]) :: [FixtureInfo.t]
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
  end
end
