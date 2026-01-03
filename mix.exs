defmodule Ichi.MixProject do
  use Mix.Project

  def project do
    [
      app: :ichi,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_local_path: "plts", plt_core_path: "plts"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Ichi.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end
end
