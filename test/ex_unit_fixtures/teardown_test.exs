defmodule ExUnitFixtures.TeardownTest do
  use ExUnit.Case

  alias ExUnitFixtures.Teardown

  test "module scoped teardown process" do
    ref = make_ref
    {:ok, agent} = Agent.start_link(fn -> false end)
    Teardown.register_pid(ref)

    Teardown.register_teardown(:module, fn ->
      Agent.update(agent, fn (called_already) ->
        assert called_already == false
        true
      end)
    end)

    assert Agent.get(agent, fn s -> s end) == false

    Teardown.run(ref)

    assert Agent.get(agent, fn s -> s end) == true
  end

  # Note: test scoped teardown relies on the ExUnit on_exit function, so is
  # not tested.
end
