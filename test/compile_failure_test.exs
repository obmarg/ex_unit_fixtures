defmodule TestCompileFailures do
  use ExUnit.Case

  test "module fixtures can't depend on test fixtures in test case" do
    assert_raise RuntimeError, ~r/Mis-matched scopes/, fn ->
      load_file("module_dep_on_test_fixture_case.exs")
    end
  end

  test "module fixtures can't depend on test fixtures in fixture module" do
    assert_raise RuntimeError, ~r/Mis-matched scopes/, fn ->
      load_file("module_dep_on_test_fixture_module.exs")
    end
  end

  defp load_file(filename) do
    [__DIR__, "compile_failure_files", filename] |> Path.join |> Code.load_file
  end
end
