defmodule ExUnitFixtures.Mixfile do
  use Mix.Project

  def project do
    [app: :ex_unit_fixtures,
     version: "0.3.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     description: description(),
     package: package(),

     name: "ExUnitFixtures",
     source_url: "https://github.com/obmarg/ex_unit_fixtures",
     homepage_url: "https://github.com/obmarg/ex_unit_fixtures",
     docs: [main: "ExUnitFixtures",
            extras: [{"README.md", [path: "README",
                                    title: "Read Me"]},
                     "CONTRIBUTING.md"]]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger],
     mod: {ExUnitFixtures, []},
     env: [auto_import: true, auto_load: true]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:dogma, "~> 0.0.11", only: :lint},
     {:credo, "~> 0.2.0", only: :lint},

     # For generating documentation.
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.11", only: :dev}
    ]
  end

  defp package do
    [
      maintainers: ["Graeme Coupar"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/obmarg/ex_unit_fixtures"}
    ]
  end

  defp description do
    """
    A modular fixture system for ExUnit, inspired by py.test fixtures.
    """
  end
end
