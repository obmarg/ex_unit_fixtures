ExUnit.start()
ExUnit.configure(capture_log: true)
ExUnitFixtures.start()

Agent.start_link(fn -> 0 end, name: :module_counter)
