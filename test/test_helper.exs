ExUnit.start()
ExUnit.configure(capture_log: true)
ExUnitFixtures.start()

Agent.start_link(fn -> 0 end, name: :module_counter)
Agent.start_link(fn -> 0 end, name: :session_counter)
Agent.start_link(fn -> 0 end, name: :session_counter2)
