defmodule Fixtures do
  use ExUnitFixtures.FixtureModule

  alias SimpleEcto.Repo

  deffixture database, scope: :module do
    #:ok = Ecto.Adapters.SQL.Sandbox.checkout(SimpleEcto.Repo)
    Ecto.Migrator.run(
      SimpleEcto.Repo,
      Application.app_dir(:simple_ecto, "priv/repo/migrations"),
      :up,
      all: true
    )
  end

  deffixture uk(database), scope: :module do
    %Country{name: "United Kingdom"} |> Repo.insert!
  end

  deffixture canada(database), scope: :module do
    %Country{name: "Canada"} |> Repo.insert!
  end

  deffixture countries(uk, canada), scope: :module do
    %{uk: uk, canada: canada}
  end

  deffixture london(uk), scope: :module do
    uk |> Ecto.build_assoc(:cities, name: "London") |> Repo.insert!
  end

  deffixture edinburgh(uk), scope: :module do
    uk |> Ecto.build_assoc(:cities, name: "Edinburgh") |> Repo.insert!
  end

  deffixture vancouver(canada), scope: :module do
    canada |> Ecto.build_assoc(:cities, name: "Vancouver") |> Repo.insert!
  end

  deffixture cities(london, edinburgh, vancouver), scope: :module do
    %{london: london, edinburgh: edinburgh, vancouver: vancouver}
  end
end
