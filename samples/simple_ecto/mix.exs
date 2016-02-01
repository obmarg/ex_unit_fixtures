defmodule SimpleEcto.Mixfile do
  use Mix.Project

  def project do
    [app: :simple_ecto,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ecto, :sqlite_ecto]]
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
    [{:ecto, "~> 1.1.0"},
     {:sqlite_ecto, "~> 1.0.0"},

     #{:ex_unit_fixtures, "~> 0.3.0", only: [:test]}]
     {:ex_unit_fixtures, github: "obmarg/ex_unit_fixtures", branch: "fix/recreating-module-fixtures", only: [:test]}]
  end
end
