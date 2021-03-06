defmodule IcsFluminusBot.MixProject do
  use Mix.Project

  def project do
    [
      app: :ics_fluminus_bot,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {IcsFluminusBot.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_gram, "~> 0.14"},
      {:fluminus, "~> 2.1"},
      {:hackney, "~> 1.12"},
      {:nimble_strftime, "~> 0.1.0"},
      {:tesla, "~> 1.2"},
      {:tzdata, "~> 1.0.1"}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
