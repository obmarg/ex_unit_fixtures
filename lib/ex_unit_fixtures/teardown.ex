defmodule ExUnitFixtures.Teardown do
  @moduledoc false

  def start_link do
    Agent.start_link(fn -> %{pids: %{}, teardowns: %{}} end, name: __MODULE__)
  end

  @doc """
  Runs teardown for the module registered as `module_ref`.
  """
  @spec run(reference) :: :ok
  def run(module_ref) when is_reference(module_ref) do
    __MODULE__
    |> Agent.get_and_update(fn (%{teardowns: tds, pids: pids}) ->
      {tds[module_ref], %{teardowns: Map.delete(tds, module_ref),
                          pids: Map.delete(pids, module_ref)}}
    end)
    |> Enum.each(&apply &1, [])
  end

  @doc """
  Like `register_pid/2` but uses the current process `pid`
  """
  @spec register_pid(reference) :: :ok
  def register_pid(module_ref) when is_reference(module_ref) do
    register_pid(module_ref, self)
  end

  @doc """
  Associates `pid` with `module_ref`
  """
  @spec register_pid(reference, pid) :: :ok
  def register_pid(module_ref, pid)
  when is_reference(module_ref)
  and is_pid(pid) do
    Agent.update(__MODULE__, fn (state = %{pids: pids, teardowns: tds}) ->
      %{state | pids: Map.put(pids, pid, module_ref),
        teardowns: Map.put(tds, module_ref, [])}
    end)
  end

  @doc """
  Registers a teardown function for the current test pid.

  For the simple case of test-scoped-fixtures this defers to
  `ExUnit.Callbacks.on_exit/1`. For module scoped fixtures, this will register
  the function to run when all the modules tests are done.
  """
  @spec register_teardown(:test | :module, fun) :: :ok
  def register_teardown(scope \\ :test, fun)

  def register_teardown(:test, fun) when is_function(fun, 0) do
    ExUnit.Callbacks.on_exit(fun)
  end

  def register_teardown(:module, fun) when is_function(fun, 0) do
    pid = self
    Agent.update(__MODULE__, fn (state = %{teardowns: tds, pids: pids}) ->
      unless Map.has_key?(pids, pid) do
        raise "register_teardown/2 can only be invoked from the test process"
      end
      new_tds = Map.update!(tds, pids[pid], fn list -> [fun|list] end)
      %{state | teardowns: new_tds}
    end)
  end
end
